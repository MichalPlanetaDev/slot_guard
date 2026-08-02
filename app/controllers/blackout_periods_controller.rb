class BlackoutPeriodsController < WorkspaceController
  WORKSPACE_SCOPE = "workspace".freeze
  RESOURCE_SCOPE_PATTERN = /\Aresource:(?<id>\d+)\z/

  before_action :set_blackout_period,
    only: :destroy

  def index
    load_page
  end

  def create
    attributes = blackout_period_params.to_h
    scope_value = attributes.delete("scope_value")
    schedule_attributes = attributes.extract!(
      "starts_on",
      "ends_on",
      "local_starts_at",
      "local_ends_at"
    )

    unless creation_allowed?(scope_value)
      redirect_to blackout_periods_path,
        alert: authorization_message(
          workspace_wide: workspace_scope?(scope_value)
        ),
        status: :see_other
      return
    end

    @blackout_period = Current.workspace
      .blackout_periods
      .new(attributes.merge(created_by: Current.user))
    @blackout_period.scope_value = scope_value

    assign_scope(scope_value)

    @blackout_period.assign_local_schedule(
      starts_on: schedule_attributes["starts_on"],
      ends_on: schedule_attributes["ends_on"],
      local_starts_at: schedule_attributes["local_starts_at"],
      local_ends_at: schedule_attributes["local_ends_at"]
    )

    BlackoutPeriods::Create.call(@blackout_period) if
      @blackout_period.errors.empty?

    if @blackout_period.persisted?
      redirect_to blackout_periods_path,
        notice: "Blackout period was added.",
        status: :see_other
    else
      assign_failed_form
      load_page

      render :index,
        status: :unprocessable_entity
    end
  end

  def destroy
    unless management_allowed?(@blackout_period)
      redirect_to blackout_periods_path,
        alert: authorization_message(
          workspace_wide: @blackout_period.workspace_wide?
        ),
        status: :see_other
      return
    end

    @blackout_period.destroy!

    redirect_to blackout_periods_path,
      notice: "Blackout period was removed.",
      status: :see_other
  end

  private

  def set_blackout_period
    @blackout_period = Current.workspace
      .blackout_periods
      .find(params[:id])
  end

  def blackout_period_params
    params.expect(
      blackout_period: %i[
        scope_value
        reason
        all_day
        starts_on
        ends_on
        local_starts_at
        local_ends_at
      ]
    )
  end

  def assign_scope(scope_value)
    return if workspace_scope?(scope_value)

    resource_id = resource_id_from_scope(scope_value)

    unless resource_id
      @blackout_period.errors.add(
        :scope_value,
        "must be selected"
      )
      return
    end

    resource = Current.workspace
      .shared_resources
      .active
      .find_by(id: resource_id)

    if resource
      @blackout_period.shared_resource = resource
    else
      @blackout_period.errors.add(
        :scope_value,
        "must be an active resource in this workspace"
      )
    end
  end

  def assign_failed_form
    if @blackout_period.all_day?
      @all_day_blackout_period = @blackout_period
    else
      @timed_blackout_period = @blackout_period
    end
  end

  def load_page
    @status = params[:status].presence_in(
      %w[upcoming past]
    ) || "upcoming"

    @shared_resources = Current.workspace
      .shared_resources
      .active
      .order(:name)

    @blackout_periods = filtered_blackout_periods
      .includes(:shared_resource, :created_by)

    @timed_blackout_period ||=
      new_blackout_period(all_day: false)
    @all_day_blackout_period ||=
      new_blackout_period(all_day: true)
  end

  def filtered_blackout_periods
    scope = Current.workspace.blackout_periods

    if @status == "past"
      scope.past.order(ends_at: :desc, id: :desc)
    else
      scope.current_and_future.chronological
    end
  end

  def new_blackout_period(all_day:)
    local_date = Current.workspace
      .local_time(Time.current)
      .to_date
      .next_day

    period = Current.workspace.blackout_periods.new(
      created_by: Current.user,
      all_day: all_day
    )

    if all_day
      period.starts_on = local_date.iso8601
      period.ends_on = local_date.iso8601
    else
      period.local_starts_at =
        "#{local_date.iso8601}T09:00"
      period.local_ends_at =
        "#{local_date.iso8601}T10:00"
    end

    period
  end

  def creation_allowed?(scope_value)
    if workspace_scope?(scope_value)
      can_manage_workspace_blackouts?
    else
      can_manage_resources?
    end
  end

  def management_allowed?(blackout_period)
    if blackout_period.workspace_wide?
      can_manage_workspace_blackouts?
    else
      can_manage_resources?
    end
  end

  def workspace_scope?(scope_value)
    scope_value == WORKSPACE_SCOPE
  end

  def resource_id_from_scope(scope_value)
    match = RESOURCE_SCOPE_PATTERN.match(scope_value.to_s)
    match&.[](:id)
  end

  def authorization_message(workspace_wide:)
    if workspace_wide
      "Only the workspace owner can manage workspace-wide blackouts."
    else
      "Only workspace owners and managers can manage resource blackouts."
    end
  end
end
