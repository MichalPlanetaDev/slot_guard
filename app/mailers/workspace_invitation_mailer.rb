class WorkspaceInvitationMailer < ApplicationMailer
  def invite
    @invitation = params.fetch(:invitation)
    @workspace = @invitation.workspace
    @inviter = @invitation.invited_by
    @acceptance_url =
      workspace_invitation_acceptance_url(
        params.fetch(:token)
      )

    mail(
      to: @invitation.email_address,
      subject: "Join #{@workspace.name} on SlotGuard"
    )
  end
end
