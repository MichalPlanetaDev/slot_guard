require "test_helper"

class ReservationBookingPolicyTest < ActiveSupport::TestCase
  test "enforces minimum notice and maximum advance window" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource = policy_context(
        minimum_booking_notice_minutes: 120,
        maximum_advance_booking_days: 30
      )

      too_soon = build_reservation(
        resource: resource,
        user: member,
        starts_at: Time.current + 90.minutes
      )
      too_far = build_reservation(
        resource: resource,
        user: member,
        starts_at: Time.current + 31.days
      )

      assert_not too_soon.valid?
      assert_includes(
        too_soon.errors[:starts_at],
        "must provide at least 2 hours notice"
      )

      assert_not too_far.valid?
      assert_includes(
        too_far.errors[:starts_at],
        "must be within 30 days"
      )
    end
  end

  test "a resource duration override replaces only that setting" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource = policy_context(
        minimum_booking_notice_minutes: 60,
        maximum_reservation_duration_minutes: 180
      )
      resource.update!(
        maximum_reservation_duration_minutes: 45
      )

      reservation = build_reservation(
        resource: resource,
        user: member,
        starts_at: Time.current + 2.hours,
        duration: 60.minutes
      )

      assert_not reservation.valid?
      assert_includes(
        reservation.errors[:ends_at],
        "must be within 45 minutes of the start time"
      )
      assert_equal 60,
        resource.booking_policy.minimum_booking_notice_minutes
    end
  end

  test "a reservation at each policy boundary remains valid" do
    travel_to Time.utc(2026, 8, 1, 12, 0) do
      workspace, member, resource = policy_context(
        minimum_booking_notice_minutes: 120,
        maximum_advance_booking_days: 30,
        maximum_reservation_duration_minutes: 90
      )
      starts_at = Time.current + 120.minutes
      reservation = build_reservation(
        resource: resource,
        user: member,
        starts_at: starts_at,
        duration: 90.minutes
      )

      assert reservation.valid?,
        reservation.errors.full_messages.to_sentence
    end
  end

  private

  def policy_context(**policy)
    workspace = create_workspace(**policy)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)

    0.upto(6) do |weekday|
      create_availability_window(
        shared_resource: resource,
        weekday: weekday,
        starts_minute: 0,
        ends_minute: 1_440
      )
    end

    [ workspace, member, resource ]
  end

  def build_reservation(
    resource:,
    user:,
    starts_at:,
    duration: 1.hour
  )
    Reservation.new(
      shared_resource: resource,
      user: user,
      purpose: "Policy check",
      starts_at: starts_at,
      ends_at: starts_at + duration,
      reminder_minutes: nil
    )
  end
end
