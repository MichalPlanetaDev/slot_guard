class WorkspaceInvitationMailerPreview < ActionMailer::Preview
  def invite
    workspace = Workspace.first ||
      Workspace.new(name: "Engineering Lab")
    inviter = User.first ||
      User.new(
        name: "Ada Lovelace",
        email_address: "ada@example.com"
      )
    invitation = WorkspaceInvitation.pending.first ||
      WorkspaceInvitation.new(
        workspace: workspace,
        invited_by: inviter,
        email_address: "invitee@example.com",
        role: :member,
        expires_at: 7.days.from_now
      )

    WorkspaceInvitationMailer.with(
      invitation: invitation,
      token: "preview-invitation-token"
    ).invite
  end
end
