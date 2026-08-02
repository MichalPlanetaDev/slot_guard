module BlackoutPeriodsHelper
  def blackout_period_schedule(blackout_period)
    zone = ActiveSupport::TimeZone[
      blackout_period.time_zone
    ]
    local_start = blackout_period.starts_at
      .in_time_zone(zone)
    local_end = blackout_period.ends_at
      .in_time_zone(zone)

    if blackout_period.all_day?
      blackout_date_range(
        local_start.to_date,
        (local_end - 1.second).to_date,
        blackout_period.time_zone
      )
    else
      timed_blackout_range(
        local_start,
        local_end,
        blackout_period.time_zone
      )
    end
  end

  private

  def blackout_date_range(start_date, end_date, time_zone)
    dates = if start_date == end_date
      start_date.to_fs(:long)
    else
      "#{start_date.to_fs(:long)}–#{end_date.to_fs(:long)}"
    end

    "#{dates} · all day · #{time_zone}"
  end

  def timed_blackout_range(local_start, local_end, time_zone)
    interval = if local_start.to_date == local_end.to_date
      [
        local_start.to_date.to_fs(:long),
        "#{local_start.to_fs(:time)}–#{local_end.to_fs(:time)}"
      ].join(" · ")
    else
      [
        "#{local_start.to_date.to_fs(:long)} #{local_start.to_fs(:time)}",
        "#{local_end.to_date.to_fs(:long)} #{local_end.to_fs(:time)}"
      ].join("–")
    end

    "#{interval} · #{time_zone}"
  end
end
