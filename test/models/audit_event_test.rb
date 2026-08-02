require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  setup do
    @workspace = create_workspace
    @owner = create_user(workspace: @workspace)
    @manager = create_user(
      workspace: @workspace,
      role: :manager
    )
    @member = create_user(
      workspace: @workspace,
      role: :member
    )
    @other_member = create_user(
      workspace: @workspace,
      role: :member
    )
    @resource = create_shared_resource(
      workspace: @workspace
    )
  end

  test "events are immutable in the model and database" do
    event = record_event(
      action: "resource.created",
      category: :resource,
      subject: @resource,
      subject_name: @resource.name,
      message: "Added a resource."
    )

    assert event.readonly?

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.update!(message: "Changed")
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      AuditEvent.transaction(requires_new: true) do
        AuditEvent
          .where(id: event.id)
          .update_all(message: "Changed")
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      AuditEvent.transaction(requires_new: true) do
        AuditEvent
          .where(id: event.id)
          .delete_all
      end
    end

    assert_equal "Added a resource.",
      event.reload.message
  end

  test "visibility follows owner manager and member boundaries" do
    administration = record_event(
      action: "workspace.updated",
      category: :administration,
      subject: @workspace,
      subject_name: @workspace.name,
      message: "Workspace changed."
    )
    resource = record_event(
      action: "resource.updated",
      category: :resource,
      subject: @resource,
      subject_name: @resource.name,
      message: "Resource changed."
    )
    scheduling = record_event(
      action: "blackout.created",
      category: :scheduling,
      subject: @resource,
      subject_name: @resource.name,
      message: "Blackout added."
    )
    own_reservation = record_event(
      action: "reservation.created",
      category: :reservation,
      subject: @resource,
      subject_name: "Own reservation",
      message: "Reservation created.",
      target_user: @member
    )
    other_reservation = record_event(
      action: "reservation.created",
      category: :reservation,
      subject: @resource,
      subject_name: "Other reservation",
      message: "Other reservation created.",
      target_user: @other_member
    )

    assert_equal(
      [
        administration.id,
        resource.id,
        scheduling.id,
        own_reservation.id,
        other_reservation.id
      ].sort,
      visible_ids(@owner)
    )

    assert_equal(
      [
        resource.id,
        scheduling.id,
        own_reservation.id,
        other_reservation.id
      ].sort,
      visible_ids(@manager)
    )

    assert_equal(
      [ own_reservation.id ],
      visible_ids(@member)
    )
  end

  test "the actor must belong to the event workspace" do
    outsider = create_user

    event = AuditEvent.new(
      workspace: @workspace,
      actor: outsider,
      action: "resource.created",
      category: :resource,
      subject_type: "SharedResource",
      subject_id: @resource.id,
      subject_name: @resource.name,
      actor_name: outsider.name,
      message: "Added a resource.",
      metadata: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:actor],
      "must belong to the workspace"
  end

  private

  def record_event(
    action:,
    category:,
    subject:,
    subject_name:,
    message:,
    target_user: nil
  )
    AuditEvent.record!(
      workspace: @workspace,
      actor: @owner,
      target_user: target_user,
      action: action,
      category: category,
      subject: subject,
      subject_name: subject_name,
      message: message
    )
  end

  def visible_ids(user)
    membership = user.memberships.find_by!(
      workspace: @workspace
    )

    AuditEvent
      .visible_to(membership)
      .pluck(:id)
      .sort
  end
end
