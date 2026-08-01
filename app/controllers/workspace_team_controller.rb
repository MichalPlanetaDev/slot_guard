class WorkspaceTeamController < WorkspaceController
  def show
    @memberships = Current.workspace
      .memberships
      .includes(:user)
      .order(role: :desc, created_at: :asc, id: :asc)

    @workspace_invitation =
      Current.workspace.workspace_invitations.new

    @pending_invitations = if can_manage_members?
      Current.workspace
        .workspace_invitations
        .pending
        .includes(:invited_by)
        .recent_first
    else
      WorkspaceInvitation.none
    end
  end
end
