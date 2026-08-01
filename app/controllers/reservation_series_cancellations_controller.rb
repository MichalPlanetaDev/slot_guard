class ReservationSeriesCancellationsController <
    WorkspaceController
  def create
    reservation = Current.workspace
      .reservations
      .includes(:reservation_series)
      .find(params[:reservation_id])
    reservation_series = reservation.reservation_series

    unless reservation_series
      redirect_to reservation,
        alert: "This reservation is not part of a series.",
        status: :see_other
      return
    end

    cancelled_count = reservation_series.cancel_from(
      reservation,
      actor: Current.user,
      membership: current_membership
    )

    if cancelled_count
      occurrence_label =
        "occurrence".pluralize(cancelled_count)

      redirect_to reservation_series_path(reservation_series),
        notice: "#{cancelled_count} #{occurrence_label} cancelled.",
        status: :see_other
    else
      redirect_to reservation,
        alert: reservation_series.errors.full_messages.to_sentence,
        status: :see_other
    end
  end
end
