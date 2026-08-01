class ReservationSeriesController < WorkspaceController
  before_action :set_reservation_series,
    only: :show

  def new
    @shared_resources = available_resources
    @reservation_series = ReservationSeries.new(
      user: Current.user,
      occurrence_count: 4,
      interval_weeks: 1
    )
    @reservation_series.shared_resource =
      @shared_resources.find_by(id: params[:resource_id])
  end

  def create
    @shared_resources = available_resources
    attributes = reservation_series_params.to_h
    resource_id = attributes.delete("shared_resource_id")
    submitted_starts_at =
      attributes.delete("first_starts_at")
    submitted_ends_at =
      attributes.delete("first_ends_at")

    @reservation_series = ReservationSeries.new(
      attributes.merge(user: Current.user)
    )
    @reservation_series.shared_resource =
      @shared_resources.find_by(id: resource_id)

    assign_workspace_time(
      :first_starts_at,
      submitted_starts_at
    )
    assign_workspace_time(
      :first_ends_at,
      submitted_ends_at
    )

    if @reservation_series.errors.empty? &&
        @reservation_series.save_with_occurrences
      redirect_to reservation_series_path(@reservation_series),
        notice: "#{@reservation_series.occurrence_count} recurring reservations were confirmed.",
        status: :see_other
    else
      render :new,
        status: :unprocessable_entity
    end
  end

  def show
    @reservations = @reservation_series
      .reservations
      .includes(:cancelled_by)
  end

  private

  def set_reservation_series
    @reservation_series = ReservationSeries
      .joins(:shared_resource)
      .where(
        shared_resources: {
          workspace_id: Current.workspace.id
        }
      )
      .includes(:shared_resource, :user)
      .find(params[:id])
  end

  def reservation_series_params
    params.expect(
      reservation_series: %i[
        shared_resource_id
        purpose
        notes
        first_starts_at
        first_ends_at
        interval_weeks
        occurrence_count
      ]
    )
  end

  def available_resources
    Current.workspace
      .shared_resources
      .active
      .order(:name)
  end

  def assign_workspace_time(attribute, submitted_value)
    return if submitted_value.blank?

    @reservation_series.public_send(
      :"#{attribute}=",
      Current.workspace.parse_local_datetime(
        submitted_value
      )
    )
  rescue Workspace::InvalidLocalTime => error
    @reservation_series.errors.add(
      attribute,
      error.message
    )
  end
end
