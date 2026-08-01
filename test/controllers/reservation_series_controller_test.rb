require "test_helper"

class ReservationSeriesControllerTest <
    ActionDispatch::IntegrationTest
  test "creates occurrences from workspace-local input" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      workspace.update!(time_zone: "Europe/Warsaw")
      member = create_user(
        workspace: workspace,
        role: :member
      )
      resource = create_shared_resource(workspace: workspace)
      create_availability_window(
        shared_resource: resource,
        weekday: 1
      )

      sign_in_as member

      assert_difference("ReservationSeries.count", 1) do
        assert_difference("Reservation.count", 4) do
          post reservation_series_collection_path, params: {
            reservation_series: {
              shared_resource_id: resource.id,
              purpose: "Weekly design review",
              first_starts_at: "2026-08-03T10:00",
              first_ends_at: "2026-08-03T11:00",
              interval_weeks: 1,
              occurrence_count: 4
            }
          }
        end
      end

      series = ReservationSeries.order(:id).last

      assert_redirected_to reservation_series_path(series)
      assert_equal "Europe/Warsaw", series.time_zone
      assert_equal(
        Time.utc(2026, 8, 3, 8, 0),
        series.reservations.first.starts_at
      )

      follow_redirect!

      assert_response :success
      assert_select "article", count: 4
    end
  end

  test "does not expose another workspace's series" do
    first_workspace = create_workspace
    second_workspace = create_workspace
    first_member = create_user(
      workspace: first_workspace,
      role: :member
    )
    second_member = create_user(
      workspace: second_workspace,
      role: :member
    )
    resource = create_shared_resource(
      workspace: second_workspace
    )
    create_availability_window(
      shared_resource: resource,
      weekday: 1
    )

    travel_to Time.utc(2026, 8, 1, 12, 0) do
      series = build_reservation_series(
        shared_resource: resource,
        user: second_member,
        first_starts_at: second_workspace.parse_local_datetime(
          "2026-08-03T10:00"
        ),
        first_ends_at: second_workspace.parse_local_datetime(
          "2026-08-03T11:00"
        ),
        occurrence_count: 2
      )
      assert series.save_with_occurrences

      sign_in_as first_member
      get reservation_series_path(series)

      assert_response :not_found
    end
  end
end
