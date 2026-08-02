require "test_helper"

class ReservationSeriesBlackoutTest < ActiveSupport::TestCase
  test "a blackout on a later occurrence rolls back the complete series" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      owner = create_user(workspace: workspace)
      member = create_user(
        workspace: workspace,
        role: :member
      )
      resource = create_shared_resource(workspace: workspace)

      create_availability_window(
        shared_resource: resource,
        weekday: 1
      )

      blocked_start = workspace.parse_local_datetime(
        "2026-08-10T10:00"
      )
      create_blackout_period(
        workspace: workspace,
        shared_resource: resource,
        created_by: owner,
        starts_at: blocked_start,
        ends_at: blocked_start + 1.hour
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
        occurrence_count: 3,
        reminder_minutes: nil
      )

      assert_no_difference("ReservationSeries.count") do
        assert_no_difference("Reservation.count") do
          assert_no_difference(
            -> {
              ScheduleBlock
                .where.not(reservation_id: nil)
                .count
            }
          ) do
            assert_not series.save_with_occurrences
          end
        end
      end

      assert_match(
        /Occurrence 2/,
        series.errors.full_messages.to_sentence
      )
      assert_match(
        /blackout period/,
        series.errors.full_messages.to_sentence
      )
    end
  end
end
