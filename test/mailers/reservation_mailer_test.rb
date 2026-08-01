require "test_helper"

class ReservationMailerTest < ActionMailer::TestCase
  test "confirmation identifies the resource, local time, and reminder" do
    reservation = mailer_reservation(
      reminder_minutes: 4 * 60
    )

    email = ReservationMailer.with(
      reservation: reservation
    ).confirmation

    assert_equal [ reservation.user.email_address ], email.to
    assert_equal(
      "Reservation confirmed: #{reservation.purpose}",
      email.subject
    )
    assert_match(
      reservation.shared_resource.name,
      email.text_part.body.to_s
    )
    assert_match(
      reservation.shared_resource.workspace.time_zone,
      email.text_part.body.to_s
    )
    assert_match(
      "4 hours before",
      email.text_part.body.to_s
    )
  end

  test "cancellation identifies the actor" do
    reservation = mailer_reservation(
      reminder_minutes: nil
    )
    reservation.cancel!(actor: reservation.user)

    email = ReservationMailer.with(
      reservation: reservation
    ).cancellation

    assert_equal(
      "Reservation cancelled: #{reservation.purpose}",
      email.subject
    )
    assert_match(
      reservation.user.name,
      email.text_part.body.to_s
    )
  end

  test "reminder links to the reservation" do
    reservation = mailer_reservation(
      reminder_minutes: 60
    )

    email = ReservationMailer.with(
      reservation: reservation
    ).reminder

    assert_equal(
      "Reminder: #{reservation.purpose}",
      email.subject
    )
    expected_url = Rails.application.routes.url_helpers.reservation_url(
      reservation,
      host: "example.com"
    )

    assert_match(
      expected_url,
      email.text_part.body.to_s
    )
  end

  private

  def mailer_reservation(reminder_minutes:)
    workspace = create_workspace
    workspace.update!(time_zone: "Europe/Warsaw")
    user = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(
      workspace: workspace,
      name: "Design Studio"
    )
    starts_at = 2.days.from_now.change(
      hour: 10,
      min: 0
    )

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.in_time_zone(
        workspace.local_time_zone
      ).wday
    )

    create_reservation(
      shared_resource: resource,
      user: user,
      starts_at: starts_at,
      ends_at: starts_at + 1.hour,
      purpose: "Design review",
      reminder_minutes: reminder_minutes
    )
  end
end
