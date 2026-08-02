class WorkspaceInvitationsController < WorkspaceController
  before_action :require_member_management_access

  def create
    attributes = invitation_params.to_h.symbolize_keys
    email_address =
      attributes.fetch(:email_address).to_s.strip.downcase

    invitation = Current.workspace
      .workspace_invitations
      .pending
      .find_or_initialize_by(email_address: email_address)

    invitation.assign_attributes(
      invited_by: Current.user,
      role: attributes.fetch(:role)
    )
    invitation.rotate_delivery_token

    saved = WorkspaceInvitation.transaction do
      if invitation.save
        # Synchronous delivery keeps the raw token out of persisted job payloads.
        WorkspaceInvitationMailer.with(
          invitation: invitation,
          token: invitation.delivery_token
        ).invite.deliver_now

        AuditEvent.record!(
          workspace: Current.workspace,
          actor: Current.user,
          action: "invitation.sent",
          category: :administration,
          subject: invitation,
          subject_name: invitation.email_address,
          message: "Invited #{invitation.email_address} as #{invitation.role}.",
          metadata: {
            role: invitation.role
          }
        )

        true
      else
        false
      end
    end

    if saved
      redirect_to workspace_team_path,
        notice: "Invitation sent to #{invitation.email_address}.",
        status: :see_other
    else
      redirect_to workspace_team_path,
        alert: invitation.errors.full_messages.to_sentence,
        status: :see_other
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to workspace_team_path,
      alert: "A pending invitation already exists for that email address.",
      status: :see_other
  end

  def destroy
    invitation = Current.workspace
      .workspace_invitations
      .pending
      .find(params[:id])

    if invitation.revoke_by(Current.user)
      redirect_to workspace_team_path,
        notice: "Invitation revoked.",
        status: :see_other
    else
      redirect_to workspace_team_path,
        alert: invitation.errors.full_messages.to_sentence,
        status: :see_other
    end
  end

  private

  def invitation_params
    params.expect(
      workspace_invitation: %i[
        email_address
        role
      ]
    )
  end
end
