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
end
