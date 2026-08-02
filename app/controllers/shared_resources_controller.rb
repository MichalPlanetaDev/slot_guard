class SharedResourcesController < WorkspaceController
  before_action :set_shared_resource,
    only: %i[show edit update archive restore]
  before_action :require_resource_management_access,
    except: %i[index show]

  def index
    @status = params[:status].presence_in(
      %w[active archived]
    ) || "active"

    @shared_resources = Current.workspace
      .shared_resources
      .public_send(@status)
      .order(:name)
  end

  def show
    load_resource_schedule
  end

  def new
    @shared_resource = Current.workspace.shared_resources.new
  end

  def create
    @shared_resource = Current.workspace
      .shared_resources
      .new(shared_resource_params)

    saved = SharedResource.transaction do
      if @shared_resource.save
        record_resource_event!(
          action: "resource.created",
          message: "Added #{@shared_resource.name}."
        )
        true
      else
        false
      end
    end

    if saved
      redirect_to @shared_resource,
        notice: "#{@shared_resource.name} was added.",
        status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render_name_conflict(:new)
  end

  def edit
  end

  def update
    updated = SharedResource.transaction do
      if @shared_resource.update(shared_resource_params)
        fields = changed_fields(@shared_resource)

        if fields.any?
          record_resource_event!(
            action: "resource.updated",
            message: "Updated #{@shared_resource.name}.",
            changed_fields: fields
          )
        end

        true
      else
        false
      end
    end

    if updated
      redirect_to @shared_resource,
        notice: "#{@shared_resource.name} was updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render_name_conflict(:edit)
  end

  def archive
    SharedResource.transaction do
      @shared_resource.update!(active: false)
      record_resource_event!(
        action: "resource.archived",
        message: "Archived #{@shared_resource.name}."
      )
    end

    redirect_to shared_resources_path(status: "archived"),
      notice: "#{@shared_resource.name} was archived.",
      status: :see_other
  end

  def restore
    SharedResource.transaction do
      @shared_resource.update!(active: true)
      record_resource_event!(
        action: "resource.restored",
        message: "Restored #{@shared_resource.name}."
      )
    end

    redirect_to @shared_resource,
      notice: "#{@shared_resource.name} is active again.",
      status: :see_other
  end

  private

  def set_shared_resource
    @shared_resource = Current.workspace
      .shared_resources
      .find(params[:id])
  end

  def load_resource_schedule
    @availability_windows = @shared_resource
      .availability_windows
      .chronological
    @availability_window = @shared_resource
      .availability_windows
      .new
    @applicable_blackout_periods = @shared_resource
      .applicable_blackout_periods
      .current_and_future
      .includes(:shared_resource, :created_by)
      .chronological
      .limit(8)
    @upcoming_reservations = @shared_resource
      .reservations
      .upcoming
      .includes(:user)
      .chronological
      .limit(8)
  end

  def shared_resource_params
    params.expect(
      shared_resource: %i[
        name
        category
        location
        capacity
        description
        minimum_booking_notice_minutes
        maximum_advance_booking_days
        maximum_reservation_duration_minutes
        cancellation_cutoff_minutes
      ]
    )
  end

  def record_resource_event!(
    action:,
    message:,
    changed_fields: []
  )
    AuditEvent.record!(
      workspace: Current.workspace,
      actor: Current.user,
      action: action,
      category: :resource,
      subject: @shared_resource,
      subject_name: @shared_resource.name,
      message: message,
      metadata: {
        changed_fields: changed_fields
      }
    )
  end

  def changed_fields(record)
    record.saved_changes.keys - %w[updated_at]
  end

  def require_resource_management_access
    return if can_manage_resources?

    redirect_to shared_resources_path,
      alert: "Only workspace owners and managers can change resources.",
      status: :see_other
  end

  def render_name_conflict(template)
    @shared_resource.errors.add(
      :name,
      "has already been used in this workspace"
    )

    render template, status: :unprocessable_entity
  end
end
