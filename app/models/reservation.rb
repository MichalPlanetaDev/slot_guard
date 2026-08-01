class Reservation < ApplicationRecord
  CONFLICT_MESSAGE =
    "That time is already reserved for this resource.".freeze
  MAXIMUM_DURATION = 12.hours

  belongs_to :shared_resource
  belongs_to :user
  belongs_to :cancelled_by,
    class_name: "User",
    optional: true

  enum :status,
    {
      confirmed: "confirmed",
      cancelled: "cancelled"
    },
    default: :confirmed,
    validate: true

  normalizes :purpose,
    with: ->(purpose) { purpose.strip.squish }
  normalizes :notes,
    with: ->(notes) { notes&.strip.presence }

  validates :purpose,
    presence: true,
    length: {
      maximum: 150
    }
  validates :notes,
    length: {
      maximum: 1_000
    },
    allow_blank: true
  validates :starts_at, :ends_at, presence: true

  validate :ends_after_start
  validate :duration_is_reasonable
  validate :cancellation_metadata_matches_status
  validate :user_belongs_to_resource_workspace
  validate :resource_is_active, on: :create
  validate :starts_in_the_future, on: :create
  validate :stays_within_one_booking_day, on: :create
  validate :fits_an_availability_window, on: :create
  validate :does_not_overlap_confirmed_reservation, on: :create

  scope :chronological, -> { order(:starts_at, :id) }
  scope :upcoming, -> {
    confirmed.where("ends_at > ?", Time.current)
  }
  scope :past, -> {
    confirmed.where("ends_at <= ?", Time.current)
  }

  def cancel!(actor:)
    with_lock do
      return self if cancelled?

      update!(
        status: :cancelled,
        cancelled_at: Time.current,
        cancelled_by: actor
      )
    end
  end

  def cancellable_by?(actor, membership:)
    confirmed? &&
      (
        user_id == actor.id ||
        membership&.can_manage_resources?
      )
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be later than the start time")
  end

  def duration_is_reasonable
    return if starts_at.blank? || ends_at.blank?
    return unless ends_at > starts_at
    return if ends_at - starts_at <= MAXIMUM_DURATION

    errors.add(:ends_at, "must be within 12 hours of the start time")
  end

  def cancellation_metadata_matches_status
    if confirmed?
      if cancelled_at.present? || cancelled_by.present?
        errors.add(
          :base,
          "A confirmed reservation cannot contain cancellation details."
        )
      end
    elsif cancelled_at.blank? || cancelled_by.blank?
      errors.add(
        :base,
        "A cancelled reservation requires its cancellation details."
      )
    end
  end

  def user_belongs_to_resource_workspace
    return unless user&.persisted? && shared_resource&.persisted?
    return if user.memberships.exists?(
      workspace_id: shared_resource.workspace_id
    )

    errors.add(
      :user,
      "must belong to the resource workspace"
    )
  end

  def resource_is_active
    return unless shared_resource
    return if shared_resource.active?

    errors.add(
      :shared_resource,
      "must be active"
    )
  end

  def starts_in_the_future
    return unless starts_at
    return if starts_at > Time.current

    errors.add(:starts_at, "must be in the future")
  end

  def stays_within_one_booking_day
    return if starts_at.blank? || ends_at.blank?
    return unless ends_at > starts_at

    local_start = starts_at.in_time_zone
    local_end = ends_at.in_time_zone

    same_day = local_end.to_date == local_start.to_date
    next_midnight =
      local_end.to_date == local_start.to_date.next_day &&
      local_end.seconds_since_midnight.zero?

    return if same_day || next_midnight

    errors.add(
      :ends_at,
      "must be on the same UTC booking day"
    )
  end

  def fits_an_availability_window
    return if starts_at.blank? || ends_at.blank?
    return unless ends_at > starts_at
    return unless shared_resource&.persisted?

    local_start = starts_at.in_time_zone
    local_end = ends_at.in_time_zone

    available = shared_resource
      .availability_windows
      .where(weekday: local_start.wday)
      .any? do |window|
        window.covers?(local_start, local_end)
      end

    unless available
      errors.add(
        :base,
        "The requested time is outside this resource's availability."
      )
    end
  end

  def does_not_overlap_confirmed_reservation
    return unless confirmed?
    return if starts_at.blank? || ends_at.blank?
    return unless ends_at > starts_at
    return unless shared_resource&.persisted?

    overlapping = shared_resource
      .reservations
      .confirmed
      .where.not(id: id)
      .where(
        <<~SQL.squish,
          tsrange(starts_at, ends_at, '[)') &&
          tsrange(
            CAST(? AS timestamp),
            CAST(? AS timestamp),
            '[)'
          )
        SQL
        starts_at,
        ends_at
      )
      .exists?

    errors.add(:base, CONFLICT_MESSAGE) if overlapping
  end
end
