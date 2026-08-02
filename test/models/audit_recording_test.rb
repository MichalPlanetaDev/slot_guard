require "test_helper"

class AuditRecordingTest < ActiveSupport::TestCase
  test "one-off reservation creation and cancellation are recorded" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times(days_from_now: 3)

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )

    reservation = Reservation.new(
      shared_resource: resource,
      user: user,
      purpose: "Project review",
      starts_at: starts_at,
      ends_at: ends_at,
      reminder_minutes: nil
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "reservation.created"
        ).count
      },
      1
    ) do
      Reservations::Create.call(reservation)
    end

    membership = user.memberships.find_by!(
      workspace: workspace
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "reservation.cancelled"
        ).count
      },
      1
    ) do
      reservation.cancel!(
        actor: user,
        membership: membership
      )
    end
  end

  test "a recurring series records one creation and one cancellation event" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times(days_from_now: 4)

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )

    series = build_reservation_series(
      shared_resource: resource,
      user: user,
      first_starts_at: starts_at,
      first_ends_at: ends_at,
      occurrence_count: 3
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "reservation_series.created"
        ).count
      },
      1
    ) do
      assert series.save_with_occurrences
    end

    assert_equal 0,
      AuditEvent.where(
        action: "reservation.created",
        workspace: workspace
      ).count

    membership = user.memberships.find_by!(
      workspace: workspace
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "reservation_series.cancelled"
        ).count
      },
      1
    ) do
      assert_equal 3,
        series.cancel_from(
          series.reservations.first,
          actor: user,
          membership: membership
        )
    end

    assert_equal 0,
      AuditEvent.where(
        action: "reservation.cancelled",
        workspace: workspace
      ).count
  end

  test "blackout creation is recorded atomically" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times(days_from_now: 5)

    blackout = BlackoutPeriod.new(
      workspace: workspace,
      shared_resource: resource,
      created_by: owner,
      reason: "Projector maintenance",
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "blackout.created"
        ).count
      },
      1
    ) do
      BlackoutPeriods::Create.call(blackout)
    end

    assert blackout.persisted?
    assert_equal blackout.id,
      AuditEvent.find_by!(
        action: "blackout.created"
      ).subject_id
  end

  test "invitation and membership lifecycle actions are recorded" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitee = create_user(
      email_address: "audit-invitee@example.com"
    )
    invitation, = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: invitee.email_address
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "invitation.accepted"
        ).count
      },
      1
    ) do
      assert invitation.accept_by(invitee)
    end

    membership = invitee.memberships.find_by!(
      workspace: workspace
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "membership.role_changed"
        ).count
      },
      1
    ) do
      assert membership.change_role_to(
        :manager,
        by: owner
      )
    end

    assert_difference(
      -> {
        AuditEvent.where(
          action: "membership.removed"
        ).count
      },
      1
    ) do
      assert membership.remove_from_workspace(
        by: owner
      )
    end

    pending, = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner
    )

    assert_difference(
      -> {
        AuditEvent.where(
          action: "invitation.revoked"
        ).count
      },
      1
    ) do
      assert pending.revoke_by(owner)
    end
  end
end
