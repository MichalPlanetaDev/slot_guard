require "test_helper"

class ReservationBlackoutTest < ActiveSupport::TestCase
  test "a resource blackout blocks a one-off reservation" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    reservation = Reservation.new(
      shared_resource: resource,
      user: member,
      purpose: "Blocked booking",
      starts_at: starts_at,
      ends_at: ends_at,
      reminder_minutes: nil
    )

    Reservations::Create.call(reservation)

    assert_not reservation.persisted?
    assert_includes(
      reservation.errors[:base],
      Reservation::BLACKOUT_MESSAGE
    )
  end

  test "a workspace blackout blocks every resource" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    create_blackout_period(
      workspace: workspace,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    reservation = Reservation.new(
      shared_resource: resource,
      user: member,
      purpose: "Workspace closure conflict",
      starts_at: starts_at,
      ends_at: ends_at,
      reminder_minutes: nil
    )

    assert_not reservation.valid?
    assert_includes(
      reservation.errors[:base],
      Reservation::BLACKOUT_MESSAGE
    )
  end

  test "the database rejects a reservation when validations are bypassed" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    reservation = Reservation.new(
      shared_resource: resource,
      user: member,
      purpose: "Bypassed validation",
      starts_at: starts_at,
      ends_at: ends_at,
      reminder_minutes: nil
    )

    assert_no_difference("Reservation.count") do
      assert_raises(ActiveRecord::StatementInvalid) do
        Reservation.transaction(requires_new: true) do
          reservation.save!(validate: false)
        end
      end
    end
  end

  test "a reservation may start when a blackout ends" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      starts_at: starts_at - 1.hour,
      ends_at: starts_at
    )

    reservation = Reservation.new(
      shared_resource: resource,
      user: member,
      purpose: "Adjacent booking",
      starts_at: starts_at,
      ends_at: ends_at,
      reminder_minutes: nil
    )

    assert Reservations::Create.call(reservation).persisted?
  end
end
