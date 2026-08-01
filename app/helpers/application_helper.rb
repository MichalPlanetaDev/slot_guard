module ApplicationHelper
  def workspace_local_time(
    instant,
    workspace: Current.workspace
  )
    workspace.local_time(instant)
  end

  def workspace_datetime_field_value(
    instant,
    workspace: Current.workspace
  )
    workspace.local_datetime_value(instant)
  end
end
