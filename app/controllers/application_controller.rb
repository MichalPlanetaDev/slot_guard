class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_workspace

  helper_method :current_membership, :can_manage_resources?

  private

  def after_authentication_url
    dashboard_path
  end

  def set_current_workspace
    return unless Current.user

    Current.membership = Current.user
      .memberships
      .includes(:workspace)
      .order(:created_at, :id)
      .first
    Current.workspace = Current.membership&.workspace
  end

  def current_membership
    Current.membership
  end

  def can_manage_resources?
    Current.membership&.can_manage_resources?
  end
end
