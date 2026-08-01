class ReservationMailer < ApplicationMailer
  before_action :load_reservation

  def confirmation
    mail(
      to: @reservation.user.email_address,
      subject: "Reservation confirmed: #{@reservation.purpose}"
    )
  end

  def cancellation
    mail(
      to: @reservation.user.email_address,
      subject: "Reservation cancelled: #{@reservation.purpose}"
    )
  end

  def reminder
    mail(
      to: @reservation.user.email_address,
      subject: "Reminder: #{@reservation.purpose}"
    )
  end

  private

  def load_reservation
    @reservation = params.fetch(:reservation)
    @workspace = @reservation.shared_resource.workspace
    @local_start =
      @workspace.local_time(@reservation.starts_at)
    @local_end =
      @workspace.local_time(@reservation.ends_at)
    @reservation_url = reservation_url(@reservation)
  end
end
