require "test_helper"
require_relative "../test_helpers/committed_integration_test"

class ReservationSeriesNotificationsTest <
    CommittedIntegrationTest
  test "a series creates one reminder for every occurrence" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      _workspace, member, resource =
        notification_context

      sign_in_as member

      assert_difference("ReservationReminder.count", 3) do
        post reservation_series_collection_path, params: {
          reservation_series: {
            shared_resource_id: resource.id,
            purpose: "Weekly notification review",
            first_starts_at: "2026-08-03T10:00",
            first_ends_at: "2026-08-03T11:00",
            interval_weeks: 1,
            occurrence_count: 3,
            reminder_minutes: 4 * 60
          }
        }
      end

      series = ReservationSeries.order(:id).last

      assert_equal 4 * 60, series.reminder_minutes
      assert_equal(
        [ 4 * 60 ],
        series.reservations
          .reorder(nil)
          .distinct
          .pluck(:reminder_minutes)
      )
      assert_equal 3, enqueued_mail_jobs.size
      assert_equal 3, enqueued_reminder_jobs.size
    end
  end

  test "future series cancellation skips the affected reminders" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource =
        notification_context
      series = build_reservation_series(
        shared_resource: resource,
        user: member,
        first_starts_at: workspace.parse_local_datetime(
          "2026-08-03T10:00"
        ),
        first_ends_at: workspace.parse_local_datetime(
          "2026-08-03T11:00"
        ),
        occurrence_count: 3,
        reminder_minutes: 4 * 60
      )
      assert series.save_with_occurrences

      second = series.reservations.find_by!(
        occurrence_number: 2
      )

      clear_enqueued_jobs
      sign_in_as member
      patch cancel_reservation_series_path(second)

      assert_redirected_to reservation_series_path(series)
      assert series.reservations.find_by!(
        occurrence_number: 1
      ).reservation_reminder.pending?
      assert series.reservations
        .where(occurrence_number: 2..3)
        .includes(:reservation_reminder)
        .all? {
          |reservation|
          reservation.reservation_reminder.skipped?
        }
      assert_equal 2, enqueued_mail_jobs.size
      assert_empty enqueued_reminder_jobs
    end
  end

  test "a failed series leaves no reminder records or notification jobs" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource =
        notification_context
      conflict_start = workspace.parse_local_datetime(
        "2026-08-10T10:00"
      )
      create_reservation(
        shared_resource: resource,
        user: member,
        starts_at: conflict_start,
        ends_at: conflict_start + 1.hour
      )

      clear_enqueued_jobs
      sign_in_as member

      assert_no_difference("ReservationSeries.count") do
        assert_no_difference("Reservation.count") do
          assert_no_difference("ReservationReminder.count") do
            post reservation_series_collection_path, params: {
              reservation_series: {
                shared_resource_id: resource.id,
                purpose: "Conflicting notification series",
                first_starts_at: "2026-08-03T10:00",
                first_ends_at: "2026-08-03T11:00",
                interval_weeks: 1,
                occurrence_count: 3,
                reminder_minutes: 4 * 60
              }
            }
          end
        end
      end

      assert_response :unprocessable_entity
      assert_empty enqueued_mail_jobs
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
