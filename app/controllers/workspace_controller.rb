class WorkspaceController < ApplicationController
  layout "workspace"

  before_action :require_workspace

  private

  def require_workspace
    return if Current.workspace

    terminate_session

    redirect_to root_path,
      alert: "Your account is not connected to a workspace.",
      status: :see_other
  end

  def require_member_management_access
    return if can_manage_members?

    redirect_to workspace_team_path,
      alert: "Only the workspace owner can manage members.",
      status: :see_other
  end
end
