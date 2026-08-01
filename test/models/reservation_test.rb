require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  test "normalizes purpose and accepts an available future time" do
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
      purpose: "  Design   review  ",
      notes: "  Bring the prototype.  ",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert reservation.valid?
    assert_equal "Design review", reservation.purpose
    assert_equal "Bring the prototype.", reservation.notes
  end

  test "rejects a time outside resource availability" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times(hour: 18)

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday,
      starts_minute: 9 * 60,
      ends_minute: 17 * 60
    )

    reservation = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Late meeting",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_not reservation.valid?
    assert_includes(
      reservation.errors[:base],
      "The requested time is outside this resource's availability."
    )
  end

  test "the database rejects overlapping confirmed reservations" do
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

    overlapping = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Conflicting reservation",
      starts_at: starts_at + 30.minutes,
      ends_at: ends_at + 30.minutes
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Reservation.transaction(requires_new: true) do
        overlapping.save!(validate: false)
      end
    end
  end

  test "allows adjacent confirmed reservations" do
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

    adjacent = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Next meeting",
      starts_at: ends_at,
      ends_at: ends_at + 1.hour
    )

    assert adjacent.valid?
  end

  test "cancellation releases the reserved time" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )
    existing = create_reservation(
      shared_resource: shared_resource,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at
    )

    existing.cancel!(actor: user)

    replacement = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Replacement",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert replacement.save
    assert existing.reload.cancelled?
    assert_equal user, existing.cancelled_by
  end

  test "rejects a user outside the resource workspace" do
    shared_resource = create_shared_resource(
      workspace: create_workspace
    )
    outsider = create_user
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )

    reservation = Reservation.new(
      shared_resource: shared_resource,
      user: outsider,
      purpose: "Outside booking",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_not reservation.valid?
    assert_includes(
      reservation.errors[:user],
      "must belong to the resource workspace"
    )
  end

  test "rejects new reservations for archived resources" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(
      workspace: workspace,
      active: false
    )
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: shared_resource,
      weekday: starts_at.wday
    )

    reservation = Reservation.new(
      shared_resource: shared_resource,
      user: user,
      purpose: "Archived booking",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_not reservation.valid?
    assert_includes(
      reservation.errors[:shared_resource],
      "must be active"
    )
  end
end
