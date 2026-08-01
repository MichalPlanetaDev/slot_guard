class WorkspaceMembershipsController < WorkspaceController
  before_action :require_member_management_access
  before_action :set_membership

  def update
    if @membership.change_role_to(
      membership_params.fetch(:role),
      by: Current.user
    )
      redirect_to workspace_team_path,
        notice: "#{@membership.user.name}'s role was updated.",
        status: :see_other
    else
      redirect_to workspace_team_path,
        alert: @membership.errors.full_messages.to_sentence,
        status: :see_other
    end
  end

  def destroy
    if @membership.remove_from_workspace(by: Current.user)
      redirect_to workspace_team_path,
        notice: "#{@membership.user.name} was removed.",
        status: :see_other
    else
      redirect_to workspace_team_path,
        alert: @membership.errors.full_messages.to_sentence,
        status: :see_other
    end
  end

  private

  def set_membership
    @membership = Current.workspace
      .memberships
      .includes(:user)
      .find(params[:id])
  end

  def membership_params
    params.expect(
      membership: %i[role]
    )
  end
end
