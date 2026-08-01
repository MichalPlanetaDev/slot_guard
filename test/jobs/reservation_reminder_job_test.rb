require "test_helper"

class ReservationReminderJobTest < ActiveJob::TestCase
  test "a cancelled reservation reminder is skipped" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace = create_workspace
      user = create_user(
        workspace: workspace,
        role: :member
      )
      resource = create_shared_resource(workspace: workspace)
      starts_at = 2.hours.from_now

      create_availability_window(
        shared_resource: resource,
        weekday: starts_at.wday
      )
      reservation = create_reservation(
        shared_resource: resource,
        user: user,
        starts_at: starts_at,
        ends_at: starts_at + 1.hour,
        reminder_minutes: 60
      )
      reminder = reservation.reservation_reminder

      reservation.cancel!(actor: user)

      assert reminder.reload.skipped?

      assert_no_difference(
        "ActionMailer::Base.deliveries.size"
      ) do
        ReservationReminderJob.perform_now(reminder)
      end

      assert reminder.reload.skipped?
    end
  end
end
