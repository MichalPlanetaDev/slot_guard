class BookingPolicy
  FIELD_LIMITS = {
    minimum_booking_notice_minutes: 0..10_080,
    maximum_advance_booking_days: 1..3_650,
    maximum_reservation_duration_minutes: 15..1_440,
    cancellation_cutoff_minutes: 0..10_080
  }.freeze
  ATTRIBUTES = FIELD_LIMITS.keys.freeze

  attr_reader :workspace, :shared_resource

  def initialize(workspace:, shared_resource: nil)
    @workspace = workspace
    @shared_resource = shared_resource
  end

  ATTRIBUTES.each do |attribute|
    define_method(attribute) do
      resource_value = shared_resource&.public_send(attribute)

      resource_value.nil? ?
        workspace.public_send(attribute) :
        resource_value
    end
  end

  def inherited?(attribute)
    ATTRIBUTES.include?(attribute) &&
      shared_resource.present? &&
      shared_resource.public_send(attribute).nil?
  end

  def earliest_start(at: Time.current)
    at + minimum_booking_notice_minutes.minutes
  end

  def latest_start(at: Time.current)
    at + maximum_advance_booking_days.days
  end

  def maximum_duration
    maximum_reservation_duration_minutes.minutes
  end

  def cancellation_deadline(starts_at)
    starts_at - cancellation_cutoff_minutes.minutes
  end

  def cancellation_open?(starts_at, at: Time.current)
    at < starts_at &&
      at <= cancellation_deadline(starts_at)
  end

  def minimum_notice_label
    return "None" if minimum_booking_notice_minutes.zero?

    duration_label(minimum_booking_notice_minutes)
  end

  def maximum_advance_label
    quantity_label(
      maximum_advance_booking_days,
      "day"
    )
  end

  def maximum_duration_label
    duration_label(
      maximum_reservation_duration_minutes
    )
  end

  def cancellation_cutoff_label
    return "Until start time" if cancellation_cutoff_minutes.zero?

    "#{duration_label(cancellation_cutoff_minutes)} before start"
  end

  def cancellation_requirement
    return "before the reservation starts" if
      cancellation_cutoff_minutes.zero?

    "at least #{duration_label(cancellation_cutoff_minutes)} " \
      "before the reservation starts"
  end

  private

  def duration_label(minutes)
    if (minutes % 1_440).zero?
      quantity_label(minutes / 1_440, "day")
    elsif (minutes % 60).zero?
      quantity_label(minutes / 60, "hour")
    else
      quantity_label(minutes, "minute")
    end
  end

  def quantity_label(quantity, unit)
    "#{quantity} #{unit.pluralize(quantity)}"
  end
end
