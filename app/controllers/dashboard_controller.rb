class DashboardController < WorkspaceController
  def show
    @active_resources = Current.workspace
      .shared_resources
      .active
      .order(:name)
      .limit(5)

    @resource_counts = Current.workspace
      .shared_resources
      .active
      .group(:category)
      .count
  end
end
