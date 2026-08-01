require "test_helper"

class WorkspaceInvitationTest < ActiveSupport::TestCase
  test "stores a digest instead of the delivery token" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, token = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner
    )

    assert token.present?
    assert_not_equal token, invitation.token_digest
    assert_equal(
      invitation,
      WorkspaceInvitation.find_by_delivery_token(token)
    )
  end

  test "rotating delivery invalidates the previous link" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, previous_token =
      create_workspace_invitation(
        workspace: workspace,
        invited_by: owner
      )

    invitation.rotate_delivery_token
    current_token = invitation.delivery_token
    invitation.save!

    assert_nil(
      WorkspaceInvitation.find_by_delivery_token(previous_token)
    )
    assert_equal(
      invitation,
      WorkspaceInvitation.find_by_delivery_token(current_token)
    )
  end

  test "acceptance keeps the personal workspace and adds the invited one" do
    invited_workspace = create_workspace
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

    membership = invitation.accept_by(invitee)

    assert membership.manager?
    assert_equal invited_workspace, membership.workspace
    assert_equal 2, invitee.memberships.reload.count
    assert invitation.reload.accepted?
    assert_nil(
      WorkspaceInvitation.find_by_delivery_token(token)
    )
  end

  test "acceptance requires the invited email address" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: "invitee@example.com"
    )
    different_user = create_user(
      email_address: "different@example.com"
    )

    membership = invitation.accept_by(different_user)

    assert_nil membership
    assert invitation.reload.pending?
    assert_includes(
      invitation.errors[:base],
      "Sign in with invitee@example.com to accept this invitation."
    )
  end

  test "expired invitations cannot be accepted" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitee = create_user(
      email_address: "invitee@example.com"
    )
    invitation, = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: invitee.email_address
    )

    travel_to(invitation.expires_at + 1.minute) do
      membership = invitation.accept_by(invitee)

      assert_nil membership
      assert invitation.reload.pending?
      assert_includes(
        invitation.errors[:base],
        "This invitation has expired. Ask the workspace owner to resend it."
      )
    end
  end

  test "revocation consumes the delivery token" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, token = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner
    )

    assert invitation.revoke_by(owner)

    assert invitation.reload.revoked?
    assert_equal owner, invitation.revoked_by
    assert_nil(
      WorkspaceInvitation.find_by_delivery_token(token)
    )
  end

  test "the database rejects an inconsistent terminal state" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    invitation, = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      WorkspaceInvitation.transaction(requires_new: true) do
        invitation.update_columns(
          accepted_at: Time.current
        )
      end
    end
  end
end
