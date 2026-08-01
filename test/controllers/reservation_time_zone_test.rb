require "test_helper"

class ReservationTimeZoneTest <
    ActionDispatch::IntegrationTest
  test "stores workspace-local input as UTC and renders local time" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace(name: "Warsaw Lab")
      workspace.update!(time_zone: "Europe/Warsaw")
      member = create_user(
        workspace: workspace,
        role: :member
      )
      resource = create_shared_resource(
        workspace: workspace,
        name: "Studio A"
      )

      create_availability_window(
        shared_resource: resource,
        weekday: 1,
        starts_minute: 9 * 60,
        ends_minute: 17 * 60
      )

      sign_in_as member

      assert_difference("Reservation.count", 1) do
        post reservations_path, params: {
          reservation: {
            shared_resource_id: resource.id,
            purpose: "Local design review",
            starts_at: "2026-08-03T10:00",
            ends_at: "2026-08-03T11:00"
          }
        }
      end

      reservation = Reservation.order(:id).last

      assert_equal(
        Time.utc(2026, 8, 3, 8, 0),
        reservation.starts_at
      )
      assert_equal(
        Time.utc(2026, 8, 3, 9, 0),
        reservation.ends_at
      )

      follow_redirect!

      assert_response :success
      assert_select "body", text: /10:00/
      assert_select "body", text: /Europe\/Warsaw/
    end
  end

  test "availability is evaluated in the resource workspace time zone" do
    workspace = create_workspace
    workspace.update!(time_zone: "Europe/Warsaw")
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)

    create_availability_window(
      shared_resource: resource,
      weekday: 1,
      starts_minute: 9 * 60,
      ends_minute: 17 * 60
    )

    starts_at = workspace.parse_local_datetime(
      "2026-08-03T10:00"
    )
    ends_at = workspace.parse_local_datetime(
      "2026-08-03T11:00"
    )

    reservation = Reservation.new(
      shared_resource: resource,
      user: member,
      purpose: "Workspace-local reservation",
      starts_at: starts_at,
      ends_at: ends_at
    )

    travel_to Time.utc(2026, 8, 1, 12, 0) do
      assert reservation.valid?
    end
  end

  test "a skipped daylight-saving time returns a field error" do
    travel_to Time.utc(2026, 3, 1, 12, 0) do
      workspace = create_workspace
      workspace.update!(time_zone: "Europe/Warsaw")
      member = create_user(
        workspace: workspace,
        role: :member
      )
      resource = create_shared_resource(workspace: workspace)

      create_availability_window(
        shared_resource: resource,
        weekday: 0,
        starts_minute: 0,
        ends_minute: 5 * 60
      )

      sign_in_as member

      assert_no_difference("Reservation.count") do
        post reservations_path, params: {
          reservation: {
            shared_resource_id: resource.id,
            purpose: "DST transition",
            starts_at: "2026-03-29T02:30",
            ends_at: "2026-03-29T03:30"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "[role='alert']",
        text: /does not exist in Europe\/Warsaw/
    end
  end
end
