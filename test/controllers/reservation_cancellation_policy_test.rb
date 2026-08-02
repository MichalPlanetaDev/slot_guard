require "test_helper"

class ReservationCancellationPolicyTest <
    ActionDispatch::IntegrationTest
  test "a member can cancel before the cutoff" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      reservation, member = cancellation_context(
        starts_at: Time.utc(2026, 8, 3, 12, 0),
        cutoff_minutes: 24 * 60
      )

      sign_in_as member
      patch cancel_reservation_path(reservation)

      assert_redirected_to reservation_path(reservation)
      assert reservation.reload.cancelled?
    end
  end

  test "a member cannot cancel after the cutoff" do
    travel_to Time.utc(2026, 8, 2, 13, 0) do
      reservation, member = cancellation_context(
        starts_at: Time.utc(2026, 8, 3, 12, 0),
        cutoff_minutes: 24 * 60
      )

      sign_in_as member
      patch cancel_reservation_path(reservation)

      assert_redirected_to reservation_path(reservation)
      assert reservation.reload.confirmed?

      follow_redirect!

      assert_select "[role='alert']",
        text: /must be cancelled at least 1 day/
    end
  end

  test "a manager can cancel after the member cutoff" do
    travel_to Time.utc(2026, 8, 2, 13, 0) do
      reservation, = cancellation_context(
        starts_at: Time.utc(2026, 8, 3, 12, 0),
        cutoff_minutes: 24 * 60
      )
      manager = create_user(
        workspace: reservation.shared_resource.workspace,
        role: :manager
      )

      sign_in_as manager
      patch cancel_reservation_path(reservation)

      assert reservation.reload.cancelled?
      assert_equal manager, reservation.cancelled_by
    end
  end

  test "a series cancellation respects the selected occurrence cutoff" do
    travel_to Time.utc(2026, 8, 2, 13, 0) do
      workspace = create_workspace(
        cancellation_cutoff_minutes: 24 * 60
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
        first_starts_at: Time.utc(2026, 8, 3, 12, 0),
        first_ends_at: Time.utc(2026, 8, 3, 13, 0)
      )
      assert series.save_with_occurrences

      selected = series.reservations.first

      sign_in_as member

      assert_no_changes(
        -> { series.reservations.reload.pluck(:status) }
      ) do
        patch cancel_reservation_series_path(selected)
      end

      assert_redirected_to reservation_path(selected)
    end
  end

  private

  def cancellation_context(starts_at:, cutoff_minutes:)
    workspace = create_workspace(
      cancellation_cutoff_minutes: cutoff_minutes
    )
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday,
      starts_minute: 0,
      ends_minute: 1_440
    )

    reservation = create_reservation(
      shared_resource: resource,
      user: member,
      starts_at: starts_at,
      ends_at: starts_at + 1.hour
    )

    [ reservation, member ]
  end
end
