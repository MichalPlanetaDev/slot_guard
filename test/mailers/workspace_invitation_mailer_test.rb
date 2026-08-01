require "test_helper"

class WorkspaceInvitationMailerTest < ActionMailer::TestCase
  test "identifies the workspace, inviter, role, and acceptance link" do
    workspace = create_workspace(name: "Engineering Lab")
    owner = create_user(
      name: "Ada Lovelace",
      workspace: workspace
    )
    invitation, token = create_workspace_invitation(
      workspace: workspace,
      invited_by: owner,
      email_address: "invitee@example.com",
      role: :manager
    )

    email = WorkspaceInvitationMailer.with(
      invitation: invitation,
      token: token
    ).invite

    assert_equal(
      [ "invitee@example.com" ],
      email.to
    )
    assert_equal(
      "Join Engineering Lab on SlotGuard",
      email.subject
    )
    assert_match "Ada Lovelace",
      email.text_part.body.to_s
    assert_match "manager",
      email.text_part.body.to_s
    assert_match token,
      email.text_part.body.to_s
  end
end
