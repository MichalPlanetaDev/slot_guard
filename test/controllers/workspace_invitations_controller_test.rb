require "test_helper"

class WorkspaceInvitationsControllerTest <
    ActionDispatch::IntegrationTest
  test "an owner can send an invitation" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)

    sign_in_as owner

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      assert_difference("WorkspaceInvitation.count", 1) do
        post workspace_invitations_path, params: {
          workspace_invitation: {
            email_address: "Invitee@example.com",
            role: "manager"
          }
        }
      end
    end

    invitation = WorkspaceInvitation.order(:id).last

    assert_equal "invitee@example.com",
      invitation.email_address
    assert invitation.manager?
    assert_redirected_to workspace_team_path
  end

  test "sending again rotates the existing invitation" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, previous_token =
      create_workspace_invitation(
        workspace: workspace,
        invited_by: owner,
        email_address: "invitee@example.com"
      )

    sign_in_as owner

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      assert_no_difference("WorkspaceInvitation.count") do
        post workspace_invitations_path, params: {
          workspace_invitation: {
            email_address: "INVITEE@example.com",
            role: "manager"
          }
        }
      end
    end

    assert invitation.reload.manager?
    assert_nil(
      WorkspaceInvitation.find_by_delivery_token(previous_token)
    )
    assert_redirected_to workspace_team_path
  end

  test "a manager cannot send invitations" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )

    sign_in_as manager

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      assert_no_difference("WorkspaceInvitation.count") do
        post workspace_invitations_path, params: {
          workspace_invitation: {
            email_address: "invitee@example.com",
            role: "member"
          }
        }
      end
    end

    assert_redirected_to workspace_team_path
  end

  test "an existing member cannot be invited" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )

    sign_in_as owner

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      assert_no_difference("WorkspaceInvitation.count") do
        post workspace_invitations_path, params: {
          workspace_invitation: {
            email_address: member.email_address,
            role: "member"
          }
        }
      end
    end

    assert_redirected_to workspace_team_path
  end

  test "an owner can revoke a pending invitation" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, token = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner
    )

    sign_in_as owner
    delete workspace_invitation_path(invitation)

    assert_redirected_to workspace_team_path
    assert invitation.reload.revoked?
    assert_nil(
      WorkspaceInvitation.find_by_delivery_token(token)
    )
  end
end
