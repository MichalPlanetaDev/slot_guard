class CurrentWorkspacesController < WorkspaceController
  def update
    membership = Current.user.memberships.find_by!(
      workspace_id: params.require(:workspace_id)
    )

    session[:workspace_id] = membership.workspace_id

    redirect_to dashboard_path,
      notice: "Switched to #{membership.workspace.name}.",
      status: :see_other
  end
end
