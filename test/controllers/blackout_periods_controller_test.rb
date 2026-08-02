require "test_helper"

class BlackoutPeriodsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get blackout_periods_path

    assert_redirected_to new_session_path
  end

  test "members can review blackouts but cannot add them" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times
    blackout = create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at,
      reason: "Visible maintenance"
    )

    sign_in_as member
    get blackout_periods_path

    assert_response :success
    assert_select "body", text: /#{blackout.reason}/
    assert_select "form[action='#{blackout_periods_path}']",
      count: 0

    assert_no_difference("BlackoutPeriod.count") do
      post blackout_periods_path, params: {
        blackout_period: {
          scope_value: "resource:#{resource.id}",
          reason: "Unauthorized closure",
          all_day: false,
          local_starts_at: "2026-08-03T10:00",
          local_ends_at: "2026-08-03T11:00"
        }
      }
    end

    assert_redirected_to blackout_periods_path
  end

  test "a manager can create a timed resource blackout" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      manager = create_user(
        workspace: workspace,
        role: :manager
      )
      resource = create_shared_resource(workspace: workspace)

      sign_in_as manager

      assert_difference("BlackoutPeriod.count", 1) do
        post blackout_periods_path, params: {
          blackout_period: {
            scope_value: "resource:#{resource.id}",
            reason: "Audio maintenance",
            all_day: false,
            local_starts_at: "2026-08-03T10:00",
            local_ends_at: "2026-08-03T12:00"
          }
        }
      end

      blackout = BlackoutPeriod.order(:id).last

      assert_redirected_to blackout_periods_path
      assert_equal resource, blackout.shared_resource
      assert_equal Time.utc(2026, 8, 3, 10, 0),
        blackout.starts_at
      assert blackout.schedule_block.active?
    end
  end

  test "a manager cannot create a workspace-wide blackout" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      manager = create_user(
        workspace: workspace,
        role: :manager
      )

      sign_in_as manager

      assert_no_difference("BlackoutPeriod.count") do
        post blackout_periods_path, params: {
          blackout_period: {
            scope_value: "workspace",
            reason: "Workspace closure",
            all_day: true,
            starts_on: "2026-08-03",
            ends_on: "2026-08-03"
          }
        }
      end

      assert_redirected_to blackout_periods_path
    end
  end

  test "an owner can create an all-day workspace closure" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      workspace.update!(time_zone: "Europe/Warsaw")
      owner = create_user(workspace: workspace)

      sign_in_as owner

      assert_difference("BlackoutPeriod.count", 1) do
        post blackout_periods_path, params: {
          blackout_period: {
            scope_value: "workspace",
            reason: "Public holiday",
            all_day: true,
            starts_on: "2026-08-03",
            ends_on: "2026-08-03"
          }
        }
      end

      blackout = BlackoutPeriod.order(:id).last

      assert_redirected_to blackout_periods_path
      assert blackout.workspace_wide?
      assert blackout.all_day?
      assert_equal Time.utc(2026, 8, 2, 22, 0),
        blackout.starts_at
      assert_equal Time.utc(2026, 8, 3, 22, 0),
        blackout.ends_at
    end
  end

  test "confirmed reservations render a blackout conflict" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      owner = create_user(workspace: workspace)
      resource = create_shared_resource(workspace: workspace)
      starts_at = Time.utc(2026, 8, 3, 10, 0)

      create_availability_window(
        shared_resource: resource,
        weekday: starts_at.wday
      )
      create_reservation(
        shared_resource: resource,
        user: owner,
        starts_at: starts_at,
        ends_at: starts_at + 1.hour
      )

      sign_in_as owner

      assert_no_difference("BlackoutPeriod.count") do
        post blackout_periods_path, params: {
          blackout_period: {
            scope_value: "resource:#{resource.id}",
            reason: "Conflicting maintenance",
            all_day: false,
            local_starts_at: "2026-08-03T10:30",
            local_ends_at: "2026-08-03T11:30"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "[role='alert']",
        text: /Cancel the confirmed reservations/
    end
  end

  test "a manager cannot remove a workspace-wide blackout" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    starts_at, ends_at = reservation_times
    blackout = create_blackout_period(
      workspace: workspace,
      created_by: owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as manager

    assert_no_difference("BlackoutPeriod.count") do
      delete blackout_period_path(blackout)
    end

    assert_redirected_to blackout_periods_path
  end

  test "a manager can remove a resource blackout" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times
    blackout = create_blackout_period(
      workspace: workspace,
      shared_resource: resource,
      created_by: manager,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as manager

    assert_difference("BlackoutPeriod.count", -1) do
      delete blackout_period_path(blackout)
    end

    assert_redirected_to blackout_periods_path
    assert_not ScheduleBlock.exists?(
      blackout_period_id: blackout.id
    )
  end

  test "another workspace's blackout is not addressable" do
    owner = create_user
    other_workspace = create_workspace
    other_owner = create_user(workspace: other_workspace)
    starts_at, ends_at = reservation_times
    blackout = create_blackout_period(
      workspace: other_workspace,
      created_by: other_owner,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as owner
    delete blackout_period_path(blackout)

    assert_response :not_found
    assert blackout.reload.persisted?
  end
end
