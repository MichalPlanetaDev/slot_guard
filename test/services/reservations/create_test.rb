require "test_helper"

class Reservations::CreateTest < ActiveSupport::TestCase
  test "returns a persisted reservation when the slot is available" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )

    reservation = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Planning",
      starts_at: starts_at,
      ends_at: ends_at
    )

    result = Reservations::Create.call(reservation)

    assert_same reservation, result
    assert result.persisted?
  end

  test "returns conflict errors for an occupied slot" do
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

    reservation = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Overlap",
      starts_at: starts_at + 15.minutes,
      ends_at: ends_at
    )

    result = Reservations::Create.call(reservation)

    assert_not result.persisted?
    assert_includes(
      result.errors[:base],
      Reservation::CONFLICT_MESSAGE
    )
  end
end
