require "test_helper"

class AuditEventsControllerTest <
    ActionDispatch::IntegrationTest
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

    record_event(
      action: "workspace.updated",
      category: :administration,
      message: "Administration event"
    )
    record_event(
      action: "resource.updated",
      category: :resource,
      message: "Resource event"
    )
    record_event(
      action: "reservation.created",
      category: :reservation,
      message: "Member reservation event",
      target_user: @member
    )
    record_event(
      action: "reservation.created",
      category: :reservation,
      message: "Other reservation event",
      target_user: @other_member
    )
  end

  test "requires authentication" do
    get workspace_activity_path

    assert_redirected_to new_session_path
  end

  test "an owner sees the complete workspace history" do
    sign_in_as @owner
    get workspace_activity_path

    assert_response :success
    assert_match "Administration event", response.body
    assert_match "Resource event", response.body
    assert_match "Member reservation event", response.body
    assert_match "Other reservation event", response.body
  end

  test "a manager sees scheduling and resource history" do
    sign_in_as @manager
    get workspace_activity_path

    assert_response :success
    assert_no_match "Administration event", response.body
    assert_match "Resource event", response.body
    assert_match "Member reservation event", response.body
    assert_match "Other reservation event", response.body
  end

  test "a member sees only their reservation history" do
    sign_in_as @member
    get workspace_activity_path

    assert_response :success
    assert_no_match "Administration event", response.body
    assert_no_match "Resource event", response.body
    assert_match "Member reservation event", response.body
    assert_no_match "Other reservation event", response.body
  end

  private

  def record_event(
    action:,
    category:,
    message:,
    target_user: nil
  )
    AuditEvent.record!(
      workspace: @workspace,
      actor: @owner,
      target_user: target_user,
      action: action,
      category: category,
      subject: @resource,
      subject_name: @resource.name,
      message: message
    )
  end
end
