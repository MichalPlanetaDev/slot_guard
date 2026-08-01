require "test_helper"
require_relative "../test_helpers/committed_integration_test"

class ReservationNotificationsControllerTest <
    CommittedIntegrationTest
  test "a new reservation defaults to a 24 hour reminder" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      _workspace, member, resource =
        notification_context
      starts_at = Time.utc(2026, 8, 3, 10, 0)

      sign_in_as member

      assert_difference("ReservationReminder.count", 1) do
        post reservations_path, params: {
          reservation: {
            shared_resource_id: resource.id,
            purpose: "Notification review",
            starts_at: starts_at,
            ends_at: starts_at + 1.hour
          }
        }
      end

      reservation = Reservation.order(:id).last

      assert_equal 24 * 60, reservation.reminder_minutes
      assert_equal(
        starts_at - 24.hours,
        reservation.reservation_reminder.scheduled_for
      )
      assert_equal 1, enqueued_mail_jobs.size
      assert_equal 1, enqueued_reminder_jobs.size
    end
  end

  test "a member can choose no reminder" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      _workspace, member, resource =
        notification_context
      starts_at = Time.utc(2026, 8, 3, 10, 0)

      sign_in_as member

      assert_no_difference("ReservationReminder.count") do
        post reservations_path, params: {
          reservation: {
            shared_resource_id: resource.id,
            purpose: "No reminder review",
            starts_at: starts_at,
            ends_at: starts_at + 1.hour,
            reminder_minutes: ""
          }
        }
      end

      reservation = Reservation.order(:id).last

      assert_nil reservation.reminder_minutes
      assert_equal 1, enqueued_mail_jobs.size
      assert_empty enqueued_reminder_jobs
    end
  end

  test "cancellation skips the reminder and queues one email" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      _workspace, member, resource =
        notification_context
      starts_at = Time.utc(2026, 8, 3, 10, 0)
      reservation = create_reservation(
        shared_resource: resource,
        user: member,
        starts_at: starts_at,
        ends_at: starts_at + 1.hour,
        reminder_minutes: 4 * 60
      )
      reminder = reservation.reservation_reminder

      clear_enqueued_jobs
      sign_in_as member
      patch cancel_reservation_path(reservation)

      assert_redirected_to reservation_path(reservation)
      assert reminder.reload.skipped?
      assert_equal 1, enqueued_mail_jobs.size
      assert_empty enqueued_reminder_jobs
    end
  end

  private

  def notification_context
    workspace = create_workspace
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)

    create_availability_window(
      shared_resource: resource,
      weekday: 1
    )

    [ workspace, member, resource ]
  end

  def enqueued_mail_jobs
    enqueued_jobs.select {
      |job|
      job[:job] == ActionMailer::MailDeliveryJob
    }
  end

  def enqueued_reminder_jobs
    enqueued_jobs.select {
      |job|
      job[:job] == ReservationReminderJob
    }
  end
end
