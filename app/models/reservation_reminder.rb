class ReservationReminder < ApplicationRecord
  belongs_to :reservation

  validates :reservation_id, uniqueness: true
  validates :scheduled_for, presence: true

  validate :single_terminal_state

  def pending?
    delivered_at.nil? && skipped_at.nil?
  end

  def delivered?
    delivered_at.present?
  end

  def skipped?
    skipped_at.present?
  end

  def deliver_if_due!
    delivered = false
    current_time = Time.current

    self.class.transaction(requires_new: true) do
      locked_reservation = Reservation.lock.find(
        reservation_id
      )
      locked_reminder = self.class.lock.find(id)

      if locked_reminder.pending?
        if locked_reservation.cancelled? ||
            locked_reservation.starts_at <= current_time
          locked_reminder.update!(
            skipped_at: current_time
          )
        elsif locked_reminder.scheduled_for <= current_time
          # Both locks prevent cancellation or another job from racing delivery.
          ReservationMailer.with(
            reservation: locked_reservation
          ).reminder.deliver_now

          locked_reminder.update!(
            delivered_at: current_time
          )
          delivered = true
        end
      end
    end

    delivered
  end

  def skip!
    skipped = false
    current_time = Time.current

    self.class.transaction(requires_new: true) do
      Reservation.lock.find(reservation_id)
      locked_reminder = self.class.lock.find(id)

      if locked_reminder.pending?
        locked_reminder.update!(
          skipped_at: current_time
        )
        skipped = true
      end
    end

    skipped
  end

  private

  def single_terminal_state
    return unless delivered_at.present? && skipped_at.present?

    errors.add(
      :base,
      "A reminder cannot be both delivered and skipped."
    )
  end
end
