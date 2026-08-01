require "test_helper"

class ReservationReminderTest < ActiveSupport::TestCase
  test "creates one reminder at the selected lead time" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      reservation = reservation_with_reminder(
        starts_at: Time.utc(2026, 8, 3, 12, 0),
        reminder_minutes: 4 * 60
      )

      reminder = reservation.reservation_reminder

      assert_equal(
        Time.utc(2026, 8, 3, 8, 0),
        reminder.scheduled_for
      )
      assert reminder.pending?
    end
  end

  test "queues an immediate reminder when the lead time has passed" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      reservation = reservation_with_reminder(
        starts_at: 2.hours.from_now,
        reminder_minutes: 24 * 60
      )

      assert_equal(
        Time.current,
        reservation.reservation_reminder.scheduled_for
      )
    end
  end

  test "a reservation without a reminder creates no reminder record" do
    reservation = reservation_with_reminder(
      reminder_minutes: nil
    )

    assert_nil reservation.reservation_reminder
  end

  test "the database prevents duplicate reminder records" do
    reservation = reservation_with_reminder(
      reminder_minutes: 60
    )
    timestamp = Time.current

    assert_raises(ActiveRecord::RecordNotUnique) do
      ReservationReminder.transaction(requires_new: true) do
        ReservationReminder.insert_all!(
          [
            {
              reservation_id: reservation.id,
              scheduled_for: reservation.starts_at - 1.hour,
              created_at: timestamp,
              updated_at: timestamp
            }
          ]
        )
      end
    end
  end

  test "a reminder is not delivered before its schedule" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      reservation = reservation_with_reminder(
        starts_at: 2.days.from_now,
        reminder_minutes: 60
      )
      reminder = reservation.reservation_reminder

      assert_no_difference(
        "ActionMailer::Base.deliveries.size"
      ) do
        assert_not reminder.deliver_if_due!
      end

      assert reminder.reload.pending?
    end
  end

  test "duplicate delivery attempts send one email" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      reservation = reservation_with_reminder(
        starts_at: 2.hours.from_now,
        reminder_minutes: 60
      )
      reminder = reservation.reservation_reminder

      travel 61.minutes

      assert_difference(
        "ActionMailer::Base.deliveries.size",
        1
      ) do
        assert reminder.deliver_if_due!
        assert_not reminder.reload.deliver_if_due!
      end

      assert reminder.reload.delivered?
    end
  end

  test "the database rejects two terminal states" do
    reservation = reservation_with_reminder(
      reminder_minutes: 60
    )
    reminder = reservation.reservation_reminder

    assert_raises(ActiveRecord::StatementInvalid) do
      ReservationReminder.transaction(requires_new: true) do
        reminder.update_columns(
          delivered_at: Time.current,
          skipped_at: Time.current
        )
      end
    end
  end

  private

  def reservation_with_reminder(
    starts_at: 2.days.from_now.change(
      hour: 10,
      min: 0
    ),
    reminder_minutes:
  )
    workspace = create_workspace
    user = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)
    ends_at = starts_at + 1.hour

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )

    create_reservation(
      shared_resource: resource,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at,
      reminder_minutes: reminder_minutes
    )
  end
end
