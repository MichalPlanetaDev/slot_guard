require "test_helper"

class ReservationSeriesTest < ActiveSupport::TestCase
  test "keeps local wall-clock time across daylight saving" do
    travel_to Time.utc(2026, 10, 1, 12, 0) do
      workspace, member, resource = series_context(
        time_zone: "Europe/Warsaw",
        weekday: 0
      )
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: workspace.parse_local_datetime(
          "2026-10-18T10:00"
        ),
        first_ends_at: workspace.parse_local_datetime(
          "2026-10-18T11:00"
        ),
        occurrence_count: 3
      )

      assert_difference("ReservationSeries.count", 1) do
        assert_difference("Reservation.count", 3) do
          assert series.save_with_occurrences
        end
      end

      assert_equal(
        [
          Time.utc(2026, 10, 18, 8, 0),
          Time.utc(2026, 10, 25, 9, 0),
          Time.utc(2026, 11, 1, 9, 0)
        ],
        series.reservations.pluck(:starts_at)
      )
      assert_equal [ 1, 2, 3 ],
        series.reservations.pluck(:occurrence_number)
    end
  end

  test "a conflict rolls back the complete series" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource = series_context(
        weekday: 1
      )
      conflicting_start = workspace.parse_local_datetime(
        "2026-08-10T10:00"
      )
      create_reservation(
        shared_resource: resource,
        user: member,
        starts_at: conflicting_start,
        ends_at: conflicting_start + 1.hour
      )
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: workspace.parse_local_datetime(
          "2026-08-03T10:00"
        ),
        first_ends_at: workspace.parse_local_datetime(
          "2026-08-03T11:00"
        ),
        occurrence_count: 3
      )

      assert_no_difference("ReservationSeries.count") do
        assert_no_difference("Reservation.count") do
          assert_not series.save_with_occurrences
        end
      end

      assert_match(
        /Occurrence 2/,
        series.errors.full_messages.to_sentence
      )
    end
  end

  test "a nonexistent future local time rolls back the complete series" do
    travel_to Time.utc(2026, 3, 1, 12, 0) do
      workspace, member, resource = series_context(
        time_zone: "Europe/Warsaw",
        weekday: 0,
        starts_minute: 60,
        ends_minute: 4 * 60
      )
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: workspace.parse_local_datetime(
          "2026-03-22T02:30"
        ),
        first_ends_at: workspace.parse_local_datetime(
          "2026-03-22T03:30"
        ),
        occurrence_count: 2
      )

      assert_no_difference("ReservationSeries.count") do
        assert_no_difference("Reservation.count") do
          assert_not series.save_with_occurrences
        end
      end

      assert_match(
        /Occurrence 2/,
        series.errors.full_messages.to_sentence
      )
    end
  end

  test "the database requires series id and occurrence number together" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource = series_context(
        weekday: 1
      )
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: workspace.parse_local_datetime(
          "2026-08-03T10:00"
        ),
        first_ends_at: workspace.parse_local_datetime(
          "2026-08-03T11:00"
        ),
        occurrence_count: 2
      )
      assert series.save_with_occurrences

      one_off_start = workspace.parse_local_datetime(
        "2026-08-17T12:00"
      )
      one_off = create_reservation(
        shared_resource: resource,
        user: member,
        starts_at: one_off_start,
        ends_at: one_off_start + 1.hour
      )

      assert_raises(ActiveRecord::StatementInvalid) do
        Reservation.transaction(requires_new: true) do
          one_off.update_columns(
            reservation_series_id: series.id
          )
        end
      end
    end
  end

test "rolls back every occurrence inside a joinable outer transaction" do
  travel_to Time.utc(2026, 8, 1, 12, 0) do
    workspace, member, resource = series_context(
      weekday: 1
    )
    conflicting_start = workspace.parse_local_datetime(
      "2026-08-10T10:00"
    )
    create_reservation(
      shared_resource: resource,
      user: member,
      starts_at: conflicting_start,
      ends_at: conflicting_start + 1.hour
    )
    series = build_reservation_series(
      shared_resource: resource,
      user: member,
      first_starts_at: workspace.parse_local_datetime(
        "2026-08-03T10:00"
      ),
      first_ends_at: workspace.parse_local_datetime(
        "2026-08-03T11:00"
      ),
      occurrence_count: 3
    )

    ReservationSeries.transaction(
      requires_new: true,
      joinable: true
    ) do
      reservation_count = Reservation.count
      series_count = ReservationSeries.count

      assert_not series.save_with_occurrences
      assert_equal reservation_count, Reservation.count
      assert_equal series_count, ReservationSeries.count
      assert_match(
        /Occurrence 2/,
        series.errors.full_messages.to_sentence
      )

      raise ActiveRecord::Rollback
    end
  end
end

  test "a recurring reservation may end at local midnight" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource = series_context(
        weekday: 1,
        starts_minute: 23 * 60,
        ends_minute: 24 * 60
      )
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: workspace.parse_local_datetime(
          "2026-08-03T23:00"
        ),
        first_ends_at: workspace.parse_local_datetime(
          "2026-08-04T00:00"
        ),
        occurrence_count: 2
      )

      assert series.save_with_occurrences,
        series.errors.full_messages.to_sentence

      assert_equal(
        [
          Time.utc(2026, 8, 3, 23, 0),
          Time.utc(2026, 8, 10, 23, 0)
        ],
        series.reservations.pluck(:starts_at)
      )
      assert_equal(
        [
          Time.utc(2026, 8, 4, 0, 0),
          Time.utc(2026, 8, 11, 0, 0)
        ],
        series.reservations.pluck(:ends_at)
      )
    end
  end

  private

  def series_context(
    time_zone: "Etc/UTC",
    weekday:,
    starts_minute: 9 * 60,
    ends_minute: 17 * 60
  )
    workspace = create_workspace
    workspace.update!(time_zone: time_zone)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)

    create_availability_window(
      shared_resource: resource,
      weekday: weekday,
      starts_minute: starts_minute,
      ends_minute: ends_minute
    )

    [ workspace, member, resource ]
  end
end
