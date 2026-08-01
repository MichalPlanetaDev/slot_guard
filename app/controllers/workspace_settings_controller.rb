class WorkspaceSettingsController < WorkspaceController
  before_action :require_member_management_access

  def edit
    @workspace = Current.workspace
  end

  def update
    @workspace = Current.workspace

    if @workspace.update(workspace_params)
      redirect_to edit_workspace_settings_path,
        notice: "Workspace settings were updated.",
        status: :see_other
    else
      render :edit,
        status: :unprocessable_entity
    end
  end

  private

  def workspace_params
    params.expect(
      workspace: %i[
        name
        time_zone
      ]
    )
  end
end
