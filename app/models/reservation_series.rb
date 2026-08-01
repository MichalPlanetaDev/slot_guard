class ReservationSeries < ApplicationRecord
  self.table_name = "reservation_series"

  MIN_OCCURRENCES = 2
  MAX_OCCURRENCES = 26
  MAX_INTERVAL_WEEKS = 12

  belongs_to :shared_resource
  belongs_to :user

  has_many :reservations,
    -> { order(:occurrence_number) },
    dependent: :restrict_with_error,
    inverse_of: :reservation_series

  normalizes :purpose,
    with: ->(purpose) { purpose.strip.squish }

  validates :purpose,
    presence: true,
    length: {
      maximum: 150
    }
  validates :notes,
    length: {
      maximum: 1_000
    }
  validates :first_starts_at,
    :first_ends_at,
    :time_zone,
    presence: true
  validates :interval_weeks,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: MAX_INTERVAL_WEEKS
    }
  validates :occurrence_count,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: MIN_OCCURRENCES,
      less_than_or_equal_to: MAX_OCCURRENCES
    }

  before_validation :capture_workspace_time_zone,
    on: :create

  validate :resource_is_active
  validate :user_belongs_to_workspace
  validate :duration_is_permitted

  def workspace
    shared_resource&.workspace
  end

  def save_with_occurrences
    errors.clear
    return false unless valid?

    schedule = occurrence_schedule
    committed = false
    failure_message = nil

    self.class.transaction(requires_new: true) do
      save!

      schedule.each do |occurrence|
        reservation = reservations.build(
          shared_resource: shared_resource,
          user: user,
          purpose: purpose,
          notes: notes,
          starts_at: occurrence.fetch(:starts_at),
          ends_at: occurrence.fetch(:ends_at),
          occurrence_number: occurrence.fetch(:number)
        )

        Reservations::Create.call(reservation)

        next if reservation.persisted?

        failure_message =
          occurrence_error_message(reservation)
        raise ActiveRecord::Rollback
      end

      committed = true
    end

    errors.add(:base, failure_message) if failure_message
    committed
  rescue Workspace::InvalidLocalTime => error
    errors.add(:base, error.message)
    false
  end

  def cancel_from(occurrence, actor:, membership:)
    errors.clear
    cancelled_count = nil
    failure_message = nil

    self.class.transaction(requires_new: true) do
      selected_occurrence = reservations
        .lock
        .find_by(id: occurrence&.id)

      unless selected_occurrence&.confirmed? &&
          selected_occurrence.starts_at > Time.current
        failure_message =
          "Choose an upcoming confirmed occurrence."
        raise ActiveRecord::Rollback
      end

      unless selected_occurrence.cancellable_by?(
        actor,
        membership: membership
      )
        failure_message =
          "You cannot cancel this reservation series."
        raise ActiveRecord::Rollback
      end

      following_occurrences = reservations
        .confirmed
        .where(
          "occurrence_number >= ?",
          selected_occurrence.occurrence_number
        )
        .order(:occurrence_number)
        .lock
        .to_a

      following_occurrences.each do |reservation|
        reservation.cancel!(actor: actor)
      end

      cancelled_count = following_occurrences.length
    end

    errors.add(:base, failure_message) if failure_message
    cancelled_count
  rescue ActiveRecord::RecordInvalid => error
    errors.add(
      :base,
      error.record.errors.full_messages.to_sentence
    )
    nil
  end

  private

  def capture_workspace_time_zone
    self.time_zone = workspace.time_zone if workspace
  end

  def occurrence_schedule
    first_local_start = workspace.local_time(first_starts_at)
    first_local_end = workspace.local_time(first_ends_at)
    start_minute =
      (first_local_start.hour * 60) + first_local_start.min
    end_minute =
      (first_local_end.hour * 60) + first_local_end.min

    (1..occurrence_count).map do |number|
      date = first_local_start.to_date +
        ((number - 1) * interval_weeks * 7)

      begin
        starts_at = workspace.local_time_at(
          date,
          start_minute
        )
        ends_at = workspace.local_time_at(
          date,
          end_minute
        )
      rescue Workspace::InvalidLocalTime => error
        raise Workspace::InvalidLocalTime,
          "Occurrence #{number} on #{date.to_fs(:long)}: #{error.message}."
      end

      {
        number: number,
        starts_at: starts_at,
        ends_at: ends_at
      }
    end
  end

  def occurrence_error_message(reservation)
    local_date = workspace
      .local_time(reservation.starts_at)
      .to_date
      .to_fs(:long)
    details = reservation.errors.full_messages.to_sentence
    details = "could not be created" if details.blank?

    "Occurrence #{reservation.occurrence_number} on #{local_date}: #{details}"
  end

  def resource_is_active
    return unless shared_resource&.persisted?

    return if workspace
      .shared_resources
      .active
      .exists?(id: shared_resource.id)

    errors.add(
      :shared_resource,
      "must be active"
    )
  end

  def user_belongs_to_workspace
    return unless user&.persisted? && workspace&.persisted?
    return if workspace.memberships.exists?(user_id: user.id)

    errors.add(
      :user,
      "must belong to the resource workspace"
    )
  end

  def duration_is_permitted
    return unless first_starts_at && first_ends_at

    duration = first_ends_at - first_starts_at

    if duration <= 0
      errors.add(
        :first_ends_at,
        "must be after the start time"
      )
    elsif duration > 12.hours
      errors.add(
        :first_ends_at,
        "must be no more than 12 hours after the start time"
      )
    end
  end
end
