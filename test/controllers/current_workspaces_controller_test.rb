require "test_helper"

class CurrentWorkspacesControllerTest <
    ActionDispatch::IntegrationTest
  test "switches to another workspace membership" do
    personal_workspace = create_workspace(name: "Personal Lab")
    invited_workspace = create_workspace(name: "Research Lab")
    user = create_user(workspace: personal_workspace)

    Membership.create!(
      workspace: invited_workspace,
      user: user,
      role: :member
    )

    sign_in_as user
    patch current_workspace_path, params: {
      workspace_id: invited_workspace.id
    }

    assert_redirected_to dashboard_path

    follow_redirect!

    assert_response :success
    assert_select "body", text: /Research Lab/
  end

  test "cannot switch to a workspace without membership" do
    user = create_user
    inaccessible_workspace = create_workspace

    sign_in_as user
    patch current_workspace_path, params: {
      workspace_id: inaccessible_workspace.id
    }

    assert_response :not_found
  end
end
