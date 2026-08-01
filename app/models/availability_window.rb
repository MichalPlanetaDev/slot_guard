class AvailabilityWindow < ApplicationRecord
  DAY_NAMES = Date::DAYNAMES.freeze
  SLOT_INTERVAL = 30

  belongs_to :shared_resource

  validates :weekday,
    inclusion: {
      in: 0..6
    }
  validates :starts_minute,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than: 1_440
    }
  validates :ends_minute,
    numericality: {
      only_integer: true,
      greater_than: 0,
      less_than_or_equal_to: 1_440
    }

  validate :ends_after_start
  validate :does_not_overlap_existing_window

  scope :chronological, -> {
    order(:weekday, :starts_minute, :ends_minute)
  }

  def self.start_options
    (0...1_440).step(SLOT_INTERVAL).map do |minute|
      [ format_minute(minute), minute ]
    end
  end

  def self.end_options
    (SLOT_INTERVAL..1_440).step(SLOT_INTERVAL).map do |minute|
      [ format_minute(minute), minute ]
    end
  end

  def self.format_minute(minute)
    return "24:00" if minute == 1_440

    format("%02d:%02d", minute / 60, minute % 60)
  end

  def day_name
    DAY_NAMES.fetch(weekday)
  end

  def time_range
    [
      self.class.format_minute(starts_minute),
      self.class.format_minute(ends_minute)
    ].join("–")
  end

  def covers?(local_start, local_end)
    start_minute = minute_of_day(local_start)
    end_minute = end_minute_for(local_start, local_end)

    return false unless end_minute

    starts_minute <= start_minute && ends_minute >= end_minute
  end

  private

  def ends_after_start
    return if starts_minute.blank? || ends_minute.blank?
    return if ends_minute > starts_minute

    errors.add(:ends_minute, "must be later than the opening time")
  end

  def does_not_overlap_existing_window
    return unless shared_resource
    return if weekday.blank? || starts_minute.blank? || ends_minute.blank?
    return unless ends_minute > starts_minute

    overlapping = shared_resource
      .availability_windows
      .where(weekday: weekday)
      .where.not(id: id)
      .any? do |window|
        starts_minute < window.ends_minute &&
          ends_minute > window.starts_minute
      end

    if overlapping
      errors.add(
        :base,
        "This availability window overlaps an existing window."
      )
    end
  end

  def minute_of_day(time)
    (time.hour * 60) + time.min + (time.sec / 60.0)
  end

  def end_minute_for(local_start, local_end)
    return minute_of_day(local_end) if local_end.to_date == local_start.to_date

    if local_end.to_date == local_start.to_date.next_day &&
        local_end.seconds_since_midnight.zero?
      1_440
    end
  end
end
