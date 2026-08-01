class ReservationsController < WorkspaceController
  before_action :set_reservation,
    only: %i[show cancel]

  def index
    @status = params[:status].presence_in(
      %w[upcoming past cancelled]
    ) || "upcoming"

    @reservations = filtered_reservations
      .includes(:shared_resource, :user)
  end

  def show
  end

  def new
    @shared_resources = available_resources
    @reservation = Current.user.reservations.new

    selected_resource = @shared_resources.find_by(
      id: params[:resource_id]
    )
    @reservation.shared_resource = selected_resource

    apply_slot_suggestion(selected_resource)
  end

  def create
    @shared_resources = available_resources
    attributes = reservation_params.to_h
    resource_id = attributes.delete("shared_resource_id")

    @reservation = Current.user.reservations.new(attributes)
    @reservation.shared_resource = @shared_resources.find_by(
      id: resource_id
    )

    Reservations::Create.call(@reservation)

    if @reservation.persisted?
      redirect_to @reservation,
        notice: "Reservation confirmed.",
        status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    unless @reservation.cancellable_by?(
      Current.user,
      membership: current_membership
    )
      redirect_to @reservation,
        alert: "You cannot cancel this reservation.",
        status: :see_other
      return
    end

    @reservation.cancel!(actor: Current.user)

    redirect_to @reservation,
      notice: "Reservation cancelled.",
      status: :see_other
  end

  private

  def set_reservation
    @reservation = Current.workspace
      .reservations
      .find(params[:id])
  end

  def reservation_params
    params.expect(
      reservation: %i[
        shared_resource_id
        purpose
        notes
        starts_at
        ends_at
      ]
    )
  end

  def available_resources
    Current.workspace
      .shared_resources
      .active
      .order(:name)
  end

  def filtered_reservations
    scope = Current.workspace.reservations

    case @status
    when "past"
      scope.past.order(starts_at: :desc, id: :desc)
    when "cancelled"
      scope.cancelled.order(
        cancelled_at: :desc,
        id: :desc
      )
    else
      scope.upcoming.chronological
    end
  end

  def apply_slot_suggestion(shared_resource)
    return unless shared_resource

    suggestion = suggested_slot_for(shared_resource)
    return unless suggestion

    @reservation.starts_at, @reservation.ends_at = suggestion
  end

  def suggested_slot_for(shared_resource)
    windows = shared_resource
      .availability_windows
      .chronological
      .to_a

    return if windows.empty?

    today = Time.zone.today

    (0..14).each do |offset|
      date = today + offset

      windows
        .select { |window| window.weekday == date.wday }
        .each do |window|
          starts_at = time_on(date, window.starts_minute)
          next unless starts_at > Time.current

          slot_length = [
            60,
            window.ends_minute - window.starts_minute
          ].min

          return [
            starts_at,
            starts_at + slot_length.minutes
          ]
        end
    end

    nil
  end

  def time_on(date, minute)
    date = date.next_day if minute == 1_440
    minute = 0 if minute == 1_440

    Time.zone.local(
      date.year,
      date.month,
      date.day,
      minute / 60,
      minute % 60
    )
  end
end
