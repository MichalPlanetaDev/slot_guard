class Reservation < ApplicationRecord
  CONFLICT_MESSAGE =
    "That time is already reserved for this resource.".freeze
  MAXIMUM_DURATION = 12.hours
  DEFAULT_REMINDER_MINUTES = 24 * 60
  REMINDER_OPTIONS = [
    [ "No reminder", nil ],
    [ "1 hour before", 60 ],
    [ "4 hours before", 4 * 60 ],
    [ "24 hours before", DEFAULT_REMINDER_MINUTES ],
    [ "48 hours before", 48 * 60 ]
  ].freeze
  REMINDER_MINUTES = REMINDER_OPTIONS
    .filter_map { |_label, minutes| minutes }
    .freeze

  attribute :reminder_minutes,
    :integer,
    default: DEFAULT_REMINDER_MINUTES

  belongs_to :reservation_series,
    optional: true,
    inverse_of: :reservations
  belongs_to :shared_resource
  belongs_to :user
  belongs_to :cancelled_by,
    class_name: "User",
    optional: true

  has_one :reservation_reminder,
    dependent: :destroy

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
  validates :reminder_minutes,
    inclusion: {
      in: REMINDER_MINUTES
    },
    allow_nil: true

  validate :ends_after_start
  validate :duration_is_reasonable
  validate :cancellation_metadata_matches_status
  validate :user_belongs_to_resource_workspace
  validate :reservation_series_occurrence_is_consistent
  validate :resource_is_active, on: :create
  validate :starts_in_the_future, on: :create
  validate :stays_within_one_booking_day, on: :create
  validate :fits_an_availability_window, on: :create
  validate :does_not_overlap_confirmed_reservation, on: :create

  after_create :create_selected_reminder,
    if: :reminder_selected?
  after_create_commit :enqueue_confirmation_email
  after_create_commit :enqueue_reminder_delivery,
    if: :reminder_selected?
  after_update_commit :enqueue_cancellation_email,
    if: :cancelled_during_last_commit?

  scope :chronological, -> { order(:starts_at, :id) }
  scope :upcoming, -> {
    confirmed.where("ends_at > ?", Time.current)
  }
  scope :past, -> {
    confirmed.where("ends_at <= ?", Time.current)
  }

  def self.reminder_label(minutes)
    REMINDER_OPTIONS
      .find { |_label, option_minutes|
        option_minutes == minutes
      }
      &.first ||
      "No reminder"
  end

  def reminder_label
    self.class.reminder_label(reminder_minutes)
  end

  def cancel!(actor:)
    with_lock do
      return self if cancelled?

      update!(
        status: :cancelled,
        cancelled_at: Time.current,
        cancelled_by: actor
      )
      reservation_reminder&.skip!

      self
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

  def reminder_selected?
    reminder_minutes.present?
  end

  def create_selected_reminder
    desired_delivery_time =
      starts_at - reminder_minutes.minutes

    create_reservation_reminder!(
      scheduled_for: [
        desired_delivery_time,
        Time.current
      ].max
    )
  end

  def enqueue_confirmation_email
    ReservationMailer.with(
      reservation: self
    ).confirmation.deliver_later
  end

  def enqueue_reminder_delivery
    reminder = reservation_reminder
    return unless reminder

    ReservationReminderJob
      .set(wait_until: reminder.scheduled_for)
      .perform_later(reminder)
  end

  def cancelled_during_last_commit?
    saved_change_to_status? && cancelled?
  end

  def enqueue_cancellation_email
    ReservationMailer.with(
      reservation: self
    ).cancellation.deliver_later
  end

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

  def reservation_series_occurrence_is_consistent
    series = reservation_series

    if series.present? != occurrence_number.present?
      errors.add(
        :occurrence_number,
        "must be present exactly when the reservation belongs to a series"
      )
      return
    end

    return unless series

    unless shared_resource_id == series.shared_resource_id
      errors.add(
        :reservation_series,
        "must use the same resource as the reservation"
      )
    end

    return if user_id == series.user_id

    errors.add(
      :reservation_series,
      "must belong to the same user as the reservation"
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

    local_start = starts_at.in_time_zone(reservation_time_zone)
    local_end = ends_at.in_time_zone(reservation_time_zone)

    same_day = local_end.to_date == local_start.to_date
    next_midnight =
      local_end.to_date == local_start.to_date.next_day &&
      local_end.seconds_since_midnight.zero?

    return if same_day || next_midnight

    errors.add(
      :ends_at,
      "must be on the same local booking day"
    )
  end

  def fits_an_availability_window
    return if starts_at.blank? || ends_at.blank?
    return unless ends_at > starts_at
    return unless shared_resource&.persisted?

    local_start = starts_at.in_time_zone(reservation_time_zone)
    local_end = ends_at.in_time_zone(reservation_time_zone)

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

  def reservation_time_zone
    shared_resource&.workspace&.local_time_zone ||
      Time.zone
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
