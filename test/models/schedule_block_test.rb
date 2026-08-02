require "test_helper"

class ScheduleBlockTest < ActiveSupport::TestCase
  test "the database rejects overlapping resource blackouts" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    overlapping = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      reason: "Overlapping maintenance",
      starts_at: starts_at + 15.minutes,
      time_zone: workspace.time_zone,
      ends_at: ends_at + 15.minutes
    )

    error = assert_raises(
      ActiveRecord::StatementInvalid
    ) do
      BlackoutPeriod.transaction(requires_new: true) do
        overlapping.save!(validate: false)
      end
    end

    assert_equal(
      "schedule_blocks_no_overlap",
      PostgresConstraint.name(error)
    )
  end

  test "a workspace blackout conflicts with every resource in that workspace" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    first_resource = create_shared_resource(workspace: workspace)
    second_resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_blackout_period(
      workspace: workspace,
      shared_resource: first_resource,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    workspace_blackout = BlackoutPeriod.new(
      workspace: workspace,
      created_by: owner,
      reason: "Workspace closure",
      starts_at: starts_at + 15.minutes,
      time_zone: workspace.time_zone,
      ends_at: ends_at
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      BlackoutPeriod.transaction(requires_new: true) do
        workspace_blackout.save!(validate: false)
      end
    end

    second_resource_blackout = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: second_resource,
      created_by: owner,
      reason: "Independent maintenance",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert second_resource_blackout.save
  end

  test "adjacent schedule blocks are allowed" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    adjacent = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      reason: "Later maintenance",
      starts_at: ends_at,
      ends_at: ends_at + 1.hour
    )

    assert adjacent.save
  end

  test "the database prevents a blackout over a confirmed reservation" do
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
      reason: "Database conflict",
      starts_at: starts_at,
      ends_at: ends_at,
      time_zone: workspace.time_zone
    )

    assert_no_difference("BlackoutPeriod.count") do
      error = assert_raises(
        ActiveRecord::StatementInvalid
      ) do
        BlackoutPeriod.transaction(requires_new: true) do
          blackout.save!(validate: false)
        end
      end

      assert_equal(
        "schedule_blocks_no_overlap",
        PostgresConstraint.name(error)
      )
    end
  end

  test "cancelling a reservation releases its schedule block" do
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

    assert reservation.schedule_block.active?

    reservation.cancel!(actor: owner)

    assert_not reservation.schedule_block.reload.active?
  end
end
