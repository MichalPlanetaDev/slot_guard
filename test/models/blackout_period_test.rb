require "test_helper"

class BlackoutPeriodTest < ActiveSupport::TestCase
  test "assigns an inclusive all-day range in the workspace time zone" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      workspace.update!(time_zone: "Europe/Warsaw")
      owner = create_user(workspace: workspace)
      blackout = BlackoutPeriod.new(
        workspace: workspace,
        created_by: owner,
        reason: "Summer closure",
        all_day: true
      )

      assert blackout.assign_local_schedule(
        starts_on: "2026-08-03",
        ends_on: "2026-08-04",
        local_starts_at: "",
        local_ends_at: ""
      )
      assert blackout.save

      assert_equal(
        Time.utc(2026, 8, 2, 22, 0),
        blackout.starts_at
      )
      assert_equal(
        Time.utc(2026, 8, 4, 22, 0),
        blackout.ends_at
      )
      assert_equal "Europe/Warsaw", blackout.time_zone
      assert blackout.schedule_block.active?
    end
  end

  test "an all-day range follows a daylight-saving boundary" do
    travel_to Time.utc(2026, 3, 1, 12, 0) do
      workspace = create_workspace
      workspace.update!(time_zone: "Europe/Warsaw")
      owner = create_user(workspace: workspace)
      blackout = BlackoutPeriod.new(
        workspace: workspace,
        created_by: owner,
        reason: "Clock-change closure",
        all_day: true
      )

      assert blackout.assign_local_schedule(
        starts_on: "2026-03-29",
        ends_on: "2026-03-29",
        local_starts_at: "",
        local_ends_at: ""
      )
      assert blackout.save

      assert_equal(
        Time.utc(2026, 3, 28, 23, 0),
        blackout.starts_at
      )
      assert_equal(
        Time.utc(2026, 3, 29, 22, 0),
        blackout.ends_at
      )
      assert_equal(
        23.hours.to_i,
        (blackout.ends_at - blackout.starts_at).to_i
      )
    end
  end

  test "rejects a timed blackout during a nonexistent local time" do
    travel_to Time.utc(2026, 3, 1, 12, 0) do
      workspace = create_workspace
      workspace.update!(time_zone: "Europe/Warsaw")
      owner = create_user(workspace: workspace)
      blackout = BlackoutPeriod.new(
        workspace: workspace,
        created_by: owner,
        reason: "Clock-change maintenance",
        all_day: false
      )

      assert_not blackout.assign_local_schedule(
        starts_on: "",
        ends_on: "",
        local_starts_at: "2026-03-29T02:30",
        local_ends_at: "2026-03-29T04:00"
      )
      assert_includes(
        blackout.errors[:local_starts_at],
        "does not exist in Europe/Warsaw because the clock changes"
      )
    end
  end

  test "a manager can create a resource blackout" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    blackout = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: resource,
      created_by: manager,
      reason: "Lens calibration",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert blackout.valid?
  end

  test "only an owner can create a workspace-wide blackout" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    starts_at, ends_at = reservation_times

    blackout = BlackoutPeriod.new(
      workspace: workspace,
      created_by: manager,
      reason: "Office closure",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_not blackout.valid?
    assert_includes(
      blackout.errors[:base],
      "Only the workspace owner can add a workspace-wide blackout."
    )
  end

  test "a confirmed reservation prevents a conflicting blackout" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    create_reservation(
      shared_resource: resource,
      user: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    blackout = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      reason: "Maintenance",
      starts_at: starts_at + 15.minutes,
      ends_at: ends_at
    )

    assert_not blackout.valid?
    assert_includes(
      blackout.errors[:base],
      BlackoutPeriod::RESERVATION_CONFLICT_MESSAGE
    )
  end

  test "a cancelled reservation does not prevent a blackout" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    reservation = create_reservation(
      shared_resource: resource,
      user: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )
    reservation.cancel!(actor: owner)

    blackout = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      reason: "Maintenance",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert blackout.valid?
  end
end
