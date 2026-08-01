require "test_helper"

class ReservationSeriesCancellationTest <
    ActionDispatch::IntegrationTest
  test "ordinary cancellation affects one occurrence" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      series, member = create_series
      second = series.reservations.find_by!(
        occurrence_number: 2
      )
      third = series.reservations.find_by!(
        occurrence_number: 3
      )

      sign_in_as member
      patch cancel_reservation_path(second)

      assert second.reload.cancelled?
      assert third.reload.confirmed?
    end
  end

  test "series cancellation affects selected and later occurrences" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      series, member = create_series
      second = series.reservations.find_by!(
        occurrence_number: 2
      )

      sign_in_as member
      patch cancel_reservation_series_path(second)

      assert_redirected_to reservation_series_path(series)
      assert series.reservations.find_by!(
        occurrence_number: 1
      ).confirmed?
      assert series.reservations
        .where(occurrence_number: 2..4)
        .all?(&:cancelled?)
    end
  end

  test "another member cannot cancel the series" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      series, = create_series
      different_member = create_user(
        workspace: series.workspace,
        role: :member
      )
      second = series.reservations.find_by!(
        occurrence_number: 2
      )

      sign_in_as different_member

      assert_no_changes(
        -> {
          series.reservations.reload.pluck(
            :id,
            :cancelled_at,
            :cancelled_by_id
          )
        }
      ) do
        patch cancel_reservation_series_path(second)
      end

      assert_redirected_to reservation_path(second)
    end
  end

  private

  def create_series
    workspace = create_workspace
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
      first_starts_at: workspace.parse_local_datetime(
        "2026-08-03T10:00"
      ),
      first_ends_at: workspace.parse_local_datetime(
        "2026-08-03T11:00"
      )
    )
    assert series.save_with_occurrences

    [ series, member ]
  end
end
