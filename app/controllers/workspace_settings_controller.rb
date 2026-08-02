class WorkspaceSettingsController < WorkspaceController
  before_action :require_member_management_access

  def edit
    @workspace = Current.workspace
  end

  def update
    @workspace = Current.workspace

    updated = Workspace.transaction do
      if @workspace.update(workspace_params)
        fields = @workspace.saved_changes.keys - %w[updated_at]

        if fields.any?
          AuditEvent.record!(
            workspace: @workspace,
            actor: Current.user,
            action: "workspace.updated",
            category: :administration,
            subject: @workspace,
            subject_name: @workspace.name,
            message: "Updated workspace settings.",
            metadata: {
              changed_fields: fields
            }
          )
        end

        true
      else
        false
      end
    end

    if updated
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
        minimum_booking_notice_minutes
        maximum_advance_booking_days
        maximum_reservation_duration_minutes
        cancellation_cutoff_minutes
      ]
    )
  end
end
