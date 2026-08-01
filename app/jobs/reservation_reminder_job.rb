class ReservationReminderJob < ApplicationJob
  queue_as :mailers

  discard_on ActiveJob::DeserializationError

  def perform(reservation_reminder)
    reservation_reminder.deliver_if_due!
  end
end
