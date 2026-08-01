require "test_helper"

class WorkspaceTeamControllerTest <
    ActionDispatch::IntegrationTest
  test "requires authentication" do
    get workspace_team_path

    assert_redirected_to new_session_path
  end

  test "shows workspace members to an authenticated member" do
    workspace = create_workspace(name: "Engineering Lab")
    owner = create_user(workspace: workspace)
    member = create_user(
      name: "Katherine Johnson",
      workspace: workspace,
      role: :member
    )

    sign_in_as member
    get workspace_team_path

    assert_response :success
    assert_select "h1", text: "Workspace team"
    assert_select "body", text: /#{owner.name}/
    assert_select "body", text: /#{member.name}/
    assert_select(
      "form[action='#{workspace_invitations_path}']",
      count: 0
    )
  end

  test "shows invitation controls only to the owner" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: "new.member@example.com"
    )

    sign_in_as owner
    get workspace_team_path

    assert_response :success
    assert_select(
      "form[action='#{workspace_invitations_path}']"
    )
    assert_select "body",
      text: /#{invitation.email_address}/
  end
end
