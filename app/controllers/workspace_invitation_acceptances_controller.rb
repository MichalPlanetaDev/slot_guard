class WorkspaceInvitationAcceptancesController < ApplicationController
  layout "authentication"

  allow_unauthenticated_access only: :show

  before_action :set_invitation
  before_action :reject_expired_invitation

  def show
    remember_invitation
  end

  def update
    membership = @invitation.accept_by(Current.user)

    if membership
      session[:workspace_id] = membership.workspace_id
      cookies.delete(:pending_workspace_invitation)

      redirect_to dashboard_path,
        notice: "You joined #{@invitation.workspace.name}.",
        status: :see_other
    else
      render :show,
        status: :unprocessable_entity
    end
  end

  private

  def set_invitation
    @token = params[:token]
    @invitation =
      WorkspaceInvitation.find_by_delivery_token(@token)

    return if @invitation&.pending?

    cookies.delete(:pending_workspace_invitation)
    render :invalid, status: :gone
  end

  def reject_expired_invitation
    return unless @invitation.expired?

    cookies.delete(:pending_workspace_invitation)
    render :expired, status: :gone
  end

  def remember_invitation
    cookies.encrypted[:pending_workspace_invitation] = {
      value: @token,
      expires: [
        1.hour.from_now,
        @invitation.expires_at
      ].min,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end
end
