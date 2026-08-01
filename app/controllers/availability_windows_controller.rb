class AvailabilityWindowsController < WorkspaceController
  before_action :require_resource_management_access
  before_action :set_shared_resource

  def create
    @availability_window = @shared_resource
      .availability_windows
      .new(availability_window_params)

    saved = AvailabilityWindow.transaction(requires_new: true) do
      @availability_window.save
    end

    if saved
      redirect_to @shared_resource,
        notice: "Availability was added.",
        status: :see_other
    else
      render_resource
    end
  rescue ActiveRecord::StatementInvalid => error
    raise unless exclusion_violation?(error)

    @availability_window.errors.add(
      :base,
      "This availability window overlaps an existing window."
    )
    render_resource
  end

  def destroy
    availability_window = @shared_resource
      .availability_windows
      .find(params[:id])

    availability_window.destroy!

    redirect_to @shared_resource,
      notice: "Availability was removed.",
      status: :see_other
  end

  private

  def set_shared_resource
    @shared_resource = Current.workspace
      .shared_resources
      .find(params[:shared_resource_id])
  end

  def availability_window_params
    params.expect(
      availability_window: %i[
        weekday
        starts_minute
        ends_minute
      ]
    )
  end

  def require_resource_management_access
    return if can_manage_resources?

    redirect_to shared_resources_path,
      alert: "Only workspace owners and managers can change availability.",
      status: :see_other
  end

  def render_resource
    @availability_windows = @shared_resource
      .availability_windows
      .chronological
    @upcoming_reservations = @shared_resource
      .reservations
      .upcoming
      .includes(:user)
      .chronological
      .limit(8)

    render "shared_resources/show",
      status: :unprocessable_entity
  end

  def exclusion_violation?(error)
    cause = error.cause

    return true if cause.is_a?(PG::ExclusionViolation)
    return false unless cause.respond_to?(:result)

    cause.result.error_field(
      PG::Result::PG_DIAG_SQLSTATE
    ) == "23P01"
  end
end
