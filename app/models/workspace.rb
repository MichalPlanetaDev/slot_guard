require "time"

class Workspace < ApplicationRecord
  class InvalidLocalTime < StandardError
  end

  DEFAULT_TIME_ZONE = "Etc/UTC"
  LOCAL_DATETIME_PATTERN = %r{
    \A
    (?<year>\d{4})-
    (?<month>\d{2})-
    (?<day>\d{2})
    T
    (?<hour>\d{2}):
    (?<minute>\d{2})
    (?::(?<second>\d{2}))?
    \z
  }x
  EXPLICIT_ZONE_PATTERN =
    /(?:\bUTC|Z|[+-]\d{2}:?\d{2})\z/

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :workspace_invitations,
    dependent: :destroy
  has_many :shared_resources,
    dependent: :restrict_with_error
  has_many :reservations,
    through: :shared_resources

  normalizes :name, with: ->(name) { name.strip.squish }

  validates :name,
    presence: true,
    length: {
      maximum: 100
    }
  validates :time_zone,
    presence: true,
    length: {
      maximum: 100
    }

  validate :time_zone_identifier_is_valid

  def self.time_zone_options
    @time_zone_options ||= begin
      seen_identifiers = {}

      ActiveSupport::TimeZone.all.filter_map do |zone|
        identifier = zone.tzinfo.identifier
        next if seen_identifiers[identifier]

        seen_identifiers[identifier] = true

        [ zone.to_s, identifier ]
      end.freeze
    end
  end

  def local_time_zone
    ActiveSupport::TimeZone[time_zone] ||
      raise(
        InvalidLocalTime,
        "#{time_zone.inspect} is not a valid time zone."
      )
  end

  def local_time(instant)
    instant.in_time_zone(local_time_zone)
  end

  def local_datetime_value(instant)
    return if instant.blank?

    local_time(instant).strftime("%Y-%m-%dT%H:%M")
  end

  def parse_local_datetime(value)
    return value.to_time.utc if
      !value.is_a?(String) &&
      value.respond_to?(:to_time)

    submitted_value = value.to_s.strip

    if submitted_value.blank?
      raise InvalidLocalTime, "must be provided"
    end

    if EXPLICIT_ZONE_PATTERN.match?(submitted_value)
      return Time.parse(submitted_value).utc
    end

    match = LOCAL_DATETIME_PATTERN.match(submitted_value)

    unless match
      raise InvalidLocalTime,
        "must use a valid date and time"
    end

    local_time_from_components(
      year: match[:year].to_i,
      month: match[:month].to_i,
      day: match[:day].to_i,
      hour: match[:hour].to_i,
      minute: match[:minute].to_i,
      second: match[:second].to_i
    )
  rescue ArgumentError
    raise InvalidLocalTime,
      "must use a valid date and time"
  rescue TZInfo::PeriodNotFound
    raise InvalidLocalTime,
      "does not exist in #{time_zone} because the clock changes"
  rescue TZInfo::AmbiguousTime
    raise InvalidLocalTime,
      "occurs twice in #{time_zone} because the clock changes"
  end

  def local_time_at(date, minute)
    unless minute.between?(0, 1_440)
      raise ArgumentError,
        "minute must be between 0 and 1440"
    end

    if minute == 1_440
      date = date.next_day
      minute = 0
    end

    local_time_from_components(
      year: date.year,
      month: date.month,
      day: date.day,
      hour: minute / 60,
      minute: minute % 60,
      second: 0
    )
  rescue TZInfo::PeriodNotFound
    raise InvalidLocalTime,
      "does not exist in #{time_zone} because the clock changes"
  rescue TZInfo::AmbiguousTime
    raise InvalidLocalTime,
      "occurs twice in #{time_zone} because the clock changes"
  end

  private

  def local_time_from_components(
    year:,
    month:,
    day:,
    hour:,
    minute:,
    second:
  )
    unless Date.valid_date?(year, month, day) &&
        hour.between?(0, 23) &&
        minute.between?(0, 59) &&
        second.between?(0, 59)
      raise ArgumentError,
        "invalid local date or time"
    end

    local_clock = Time.utc(
      year,
      month,
      day,
      hour,
      minute,
      second
    )

    # Passing nil makes DST overlaps explicit instead of choosing arbitrarily.
    time_zone_object.local_to_utc(local_clock, nil)
  end

  def time_zone_object
    TZInfo::Timezone.get(time_zone)
  end

  def time_zone_identifier_is_valid
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(
      :time_zone,
      "must be a valid IANA time zone"
    )
  end
end
