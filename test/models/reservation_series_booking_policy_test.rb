require "test_helper"

class ReservationSeriesBookingPolicyTest <
    ActiveSupport::TestCase
  test "an out-of-window occurrence rolls back the complete series" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace(
        maximum_advance_booking_days: 10
      )
      member = create_user(
        workspace: workspace,
        role: :member
      )
      resource = create_shared_resource(workspace: workspace)
      create_availability_window(
        shared_resource: resource,
        weekday: 1
      )
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: Time.utc(2026, 8, 3, 10, 0),
        first_ends_at: Time.utc(2026, 8, 3, 11, 0),
        occurrence_count: 3
      )

      assert_no_difference("ReservationSeries.count") do
        assert_no_difference("Reservation.count") do
          assert_not series.save_with_occurrences
        end
      end

      assert_match(
        /Occurrence 3.*must be within 10 days/,
        series.errors.full_messages.to_sentence
      )
    end
  end

  test "the selected resource duration override validates the series" do
    workspace = create_workspace(
      maximum_reservation_duration_minutes: 180
    )
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(
      workspace: workspace,
      maximum_reservation_duration_minutes: 45
    )
    starts_at = 2.days.from_now.change(hour: 10)
    series = build_reservation_series(
      shared_resource: resource,
      user: member,
      first_starts_at: starts_at,
      first_ends_at: starts_at + 1.hour
    )

    assert_not series.valid?
    assert_includes(
      series.errors[:first_ends_at],
      "must be no more than 45 minutes after the start time"
    )
  end
end
