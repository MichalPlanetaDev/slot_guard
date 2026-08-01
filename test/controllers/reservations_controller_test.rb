require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get reservations_path

    assert_redirected_to new_session_path
  end

  test "lists only reservations from the current workspace" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )
    visible = create_reservation(
      shared_resource: shared_resource,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at,
      purpose: "Visible booking"
    )

    other_workspace = create_workspace
    other_user = create_user(workspace: other_workspace)
    other_resource = create_shared_resource(
      workspace: other_workspace
    )
    other_start, other_end = reservation_times(
      days_from_now: 3
    )
    create_availability_window(
      shared_resource: other_resource,
      weekday: other_start.wday
    )
    hidden = create_reservation(
      shared_resource: other_resource,
      user: other_user,
      starts_at: other_start,
      ends_at: other_end,
      purpose: "Hidden booking"
    )

    sign_in_as user
    get reservations_path

    assert_response :success
    assert_select "body", text: /#{visible.purpose}/
    assert_select "body",
      text: /#{hidden.purpose}/,
      count: 0
  end

  test "a member can create a confirmed reservation" do
    workspace = create_workspace
    member = create_user(
      workspace: workspace,
      role: :member
    )
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )

    sign_in_as member

    assert_difference("Reservation.count", 1) do
      post reservations_path, params: {
        reservation: {
          shared_resource_id: shared_resource.id,
          purpose: "Design review",
          notes: "Bring prototype",
          starts_at: starts_at,
          ends_at: ends_at
        }
      }
    end

    reservation = Reservation.order(:id).last

    assert reservation.confirmed?
    assert_equal member, reservation.user
    assert_redirected_to reservation_path(reservation)
  end

  test "an overlapping reservation renders a conflict" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )
    create_reservation(
      shared_resource: shared_resource,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as user

    assert_no_difference("Reservation.count") do
      post reservations_path, params: {
        reservation: {
          shared_resource_id: shared_resource.id,
          purpose: "Conflicting review",
          starts_at: starts_at + 30.minutes,
          ends_at: ends_at
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']",
      text: /already reserved/
  end

  test "a user can cancel their own reservation" do
    workspace = create_workspace
    user = create_user(
      workspace: workspace,
      role: :member
    )
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )
    reservation = create_reservation(
      shared_resource: shared_resource,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as user
    patch cancel_reservation_path(reservation)

    assert_redirected_to reservation_path(reservation)
    assert reservation.reload.cancelled?
    assert_equal user, reservation.cancelled_by
  end

  test "a manager can cancel another member's reservation" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    member = create_user(
      workspace: workspace,
      role: :member
    )
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )
    reservation = create_reservation(
      shared_resource: shared_resource,
      user: member,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as manager
    patch cancel_reservation_path(reservation)

    assert_redirected_to reservation_path(reservation)
    assert reservation.reload.cancelled?
    assert_equal manager, reservation.cancelled_by
  end

  test "a member cannot cancel another member's reservation" do
    workspace = create_workspace
    member = create_user(
      workspace: workspace,
      role: :member
    )
    other_member = create_user(
      workspace: workspace,
      role: :member
    )
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )
    reservation = create_reservation(
      shared_resource: shared_resource,
      user: other_member,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as member
    patch cancel_reservation_path(reservation)

    assert_redirected_to reservation_path(reservation)
    assert reservation.reload.confirmed?
  end

  test "a reservation from another workspace is not addressable" do
    user = create_user

    other_workspace = create_workspace
    other_user = create_user(workspace: other_workspace)
    other_resource = create_shared_resource(
      workspace: other_workspace
    )
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: other_resource,
      weekday: starts_at.wday
    )
    reservation = create_reservation(
      shared_resource: other_resource,
      user: other_user,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as user
    get reservation_path(reservation)

    assert_response :not_found
  end
end
