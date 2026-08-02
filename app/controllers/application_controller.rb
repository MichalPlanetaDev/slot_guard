class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_workspace

  helper_method :current_membership,
    :can_manage_resources?,
    :can_manage_members?,
    :can_manage_workspace_blackouts?,
    :available_workspace_memberships

  private

  def after_authentication_url
    invitation_token =
      cookies.encrypted[:pending_workspace_invitation]

    if invitation_token.present?
      workspace_invitation_acceptance_path(invitation_token)
    else
      dashboard_path
    end
  end

  def set_current_workspace
    return unless Current.user

    memberships = Current.user
      .memberships
      .includes(:workspace)

    # A remembered workspace is used only while its membership still exists.
    Current.membership = memberships.find_by(
      workspace_id: session[:workspace_id]
    )
    Current.membership ||= memberships.order(:created_at, :id).first
    Current.workspace = Current.membership&.workspace

    session[:workspace_id] = Current.workspace&.id
  end

  def current_membership
    Current.membership
  end

  def can_manage_resources?
    Current.membership&.can_manage_resources?
  end

  def can_manage_members?
    Current.membership&.can_manage_members?
  end

  def can_manage_workspace_blackouts?
    Current.membership&.owner?
  end

  def available_workspace_memberships
    @available_workspace_memberships ||= Current.user
      .memberships
      .includes(:workspace)
      .to_a
      .sort_by {
        |membership|
        [
          membership.workspace.name.downcase,
          membership.id
        ]
      }
  end
end
