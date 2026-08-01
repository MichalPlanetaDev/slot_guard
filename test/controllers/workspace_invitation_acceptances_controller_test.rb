require "test_helper"

class WorkspaceInvitationAcceptancesControllerTest <
    ActionDispatch::IntegrationTest
  test "shows a valid invitation without authentication" do
    workspace = create_workspace(name: "Research Lab")
    owner = create_user(workspace: workspace)
    invitation, token = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: "invitee@example.com"
    )

    get workspace_invitation_acceptance_path(token)

    assert_response :success
    assert_select "h1", text: /#{workspace.name}/
    assert_select "body",
      text: /#{invitation.email_address}/
    assert_select "a[href='#{new_session_path}']"
    assert_select "a[href='#{new_registration_path}']"
  end

  test "acceptance activates the invited workspace" do
    invited_workspace = create_workspace(name: "Research Lab")
    owner = create_user(workspace: invited_workspace)
    invitee = create_user(
      email_address: "invitee@example.com"
    )
    invitation, token = create_workspace_invitation(
      workspace: invited_workspace,
      invited_by: owner,
      email_address: invitee.email_address,
      role: :manager
    )

    sign_in_as invitee

    assert_difference("Membership.count", 1) do
      patch workspace_invitation_acceptance_path(token)
    end

    assert_redirected_to dashboard_path
    assert invitation.reload.accepted?
    assert_equal 2, invitee.memberships.reload.count

    follow_redirect!

    assert_response :success
    assert_select "body", text: /Research Lab/
  end

  test "a different account cannot accept the invitation" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    different_user = create_user(
      email_address: "different@example.com"
    )
    invitation, token = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: "invitee@example.com"
    )

    sign_in_as different_user

    assert_no_difference("Membership.count") do
      patch workspace_invitation_acceptance_path(token)
    end

    assert_response :unprocessable_entity
    assert invitation.reload.pending?
    assert_select "[role='alert']",
      text: /Sign in with invitee@example.com/
  end

  test "expired and consumed links return gone" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    expired_invitation, expired_token =
      create_workspace_invitation(
        workspace: workspace,
        invited_by: owner,
        email_address: "expired@example.com"
      )

    travel_to(expired_invitation.expires_at + 1.minute) do
      get workspace_invitation_acceptance_path(expired_token)

      assert_response :gone
      assert_select "h1", text: "Invitation expired"
    end

    invitee = create_user(
      email_address: "accepted@example.com"
    )
    accepted_invitation, accepted_token =
      create_workspace_invitation(
        workspace: workspace,
        invited_by: owner,
        email_address: invitee.email_address
      )
    accepted_invitation.accept_by(invitee)

    get workspace_invitation_acceptance_path(accepted_token)

    assert_response :gone
    assert_select "h1", text: "Invitation unavailable"
  end

  test "registration creates personal and invited memberships" do
    invited_workspace = create_workspace(name: "Research Lab")
    owner = create_user(workspace: invited_workspace)
    invitation, token = create_workspace_invitation(
      workspace: invited_workspace,
      invited_by: owner,
      email_address: "new.user@example.com"
    )

    get workspace_invitation_acceptance_path(token)

    post registration_path, params: {
      user: {
        name: "New User",
        email_address: "new.user@example.com",
        password: "correct-horse-battery-staple",
        password_confirmation: "correct-horse-battery-staple"
      }
    }

    assert_redirected_to(
      workspace_invitation_acceptance_path(token)
    )

    user = User.find_by!(
      email_address: "new.user@example.com"
    )

    assert_equal 1, user.memberships.count
    assert_equal(
      "New User's workspace",
      user.workspaces.sole.name
    )

    patch workspace_invitation_acceptance_path(token)

    assert_redirected_to dashboard_path
    assert invitation.reload.accepted?
    assert_equal 2, user.memberships.reload.count
    assert_includes user.workspaces, invited_workspace
  end
end
