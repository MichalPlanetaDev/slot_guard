require "test_helper"

class AuditEventRecordingTest <
    ActionDispatch::IntegrationTest
  test "resource lifecycle actions are recorded" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )

    sign_in_as manager

    assert_difference(
      -> {
        AuditEvent.where(
          action: "resource.created"
        ).count
      },
      1
    ) do
      post shared_resources_path, params: {
        shared_resource: {
          name: "Review Room",
          category: "room",
          location: "Floor 2",
          capacity: 8,
          description: "Project reviews"
        }
      }
    end

    resource = workspace.shared_resources.find_by!(
      name: "Review Room"
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "resource.updated"
        ).count
      },
      1
    ) do
      patch shared_resource_path(resource), params: {
        shared_resource: {
          name: "Review Room",
          category: "room",
          location: "Floor 3",
          capacity: 8,
          description: "Project reviews"
        }
      }
    end

    assert_difference(
      -> {
        AuditEvent.where(
          action: "resource.archived"
        ).count
      },
      1
    ) do
      patch archive_shared_resource_path(resource)
    end

    assert_difference(
      -> {
        AuditEvent.where(
          action: "resource.restored"
        ).count
      },
      1
    ) do
      patch restore_shared_resource_path(resource)
    end
  end

  test "workspace settings and invitations are recorded" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)

    sign_in_as owner

    assert_difference(
      -> {
        AuditEvent.where(
          action: "workspace.updated"
        ).count
      },
      1
    ) do
      patch workspace_settings_path, params: {
        workspace: {
          name: "Audited Workspace",
          time_zone: workspace.time_zone,
          minimum_booking_notice_minutes:
            workspace.minimum_booking_notice_minutes,
          maximum_advance_booking_days:
            workspace.maximum_advance_booking_days,
          maximum_reservation_duration_minutes:
            workspace.maximum_reservation_duration_minutes,
          cancellation_cutoff_minutes:
            workspace.cancellation_cutoff_minutes
        }
      }
    end

    assert_difference(
      -> {
        AuditEvent.where(
          action: "invitation.sent"
        ).count
      },
      1
    ) do
      post workspace_invitations_path, params: {
        workspace_invitation: {
          email_address: "audit@example.com",
          role: "member"
        }
      }
    end
  end

  test "removing a blackout is recorded" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times(days_from_now: 6)
    blackout = create_blackout_period(
      workspace: workspace,
      created_by: owner,
      shared_resource: resource,
      starts_at: starts_at,
      ends_at: ends_at
    )

    sign_in_as owner

    assert_difference(
      -> {
        AuditEvent.where(
          action: "blackout.removed"
        ).count
      },
      1
    ) do
      delete blackout_period_path(blackout)
    end

    assert_not BlackoutPeriod.exists?(blackout.id)
  end
end
