require "securerandom"

module UserTestData
  TEST_PASSWORD = "test-password-123"

  def create_workspace(name: nil)
    Workspace.create!(
      name: name || "Workspace #{SecureRandom.hex(5)}"
    )
  end

  def create_user(
    name: "Ada Lovelace",
    email_address: nil,
    password: TEST_PASSWORD,
    workspace: :personal,
    role: :owner
  )
    user = User.create!(
      name: name,
      email_address: email_address ||
        "user-#{SecureRandom.hex(8)}@example.com",
      password: password,
      password_confirmation: password
    )

    selected_workspace = if workspace == :personal
      create_workspace(name: "#{user.name}'s workspace")
    else
      workspace
    end

    if selected_workspace
      Membership.create!(
        workspace: selected_workspace,
        user: user,
        role: role
      )
    end

    user
  end

  def create_shared_resource(
    workspace:,
    name: nil,
    category: :room,
    **attributes
  )
    SharedResource.create!(
      {
        workspace: workspace,
        name: name || "Resource #{SecureRandom.hex(5)}",
        category: category
      }.merge(attributes)
    )
  end

  def reservation_times(
    days_from_now: 2,
    hour: 10,
    duration: 1.hour
  )
    date = Time.zone.today + days_from_now
    starts_at = Time.zone.local(
      date.year,
      date.month,
      date.day,
      hour,
      0
    )

    [ starts_at, starts_at + duration ]
  end

  def create_availability_window(
    shared_resource:,
    weekday:,
    starts_minute: 9 * 60,
    ends_minute: 17 * 60
  )
    AvailabilityWindow.create!(
      shared_resource: shared_resource,
      weekday: weekday,
      starts_minute: starts_minute,
      ends_minute: ends_minute
    )
  end

  def create_reservation(
    shared_resource:,
    user:,
    starts_at:,
    ends_at:,
    purpose: nil,
    notes: nil,
    reminder_minutes: nil
  )
    Reservation.create!(
      shared_resource: shared_resource,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at,
      purpose: purpose ||
        "Reservation #{SecureRandom.hex(4)}",
      notes: notes,
      reminder_minutes: reminder_minutes
    )
  end

  def create_blackout_period(
    workspace:,
    created_by:,
    starts_at:,
    ends_at:,
    shared_resource: nil,
    reason: "Maintenance",
    all_day: false
  )
    BlackoutPeriod.create!(
      workspace: workspace,
      shared_resource: shared_resource,
      created_by: created_by,
      reason: reason,
      starts_at: starts_at,
      ends_at: ends_at,
      all_day: all_day
    )
  end

  def create_workspace_invitation(
    workspace:,
    invited_by:,
    email_address: nil,
    role: :member
  )
    invitation = WorkspaceInvitation.create!(
      workspace: workspace,
      invited_by: invited_by,
      email_address: email_address ||
        "invitee-#{SecureRandom.hex(8)}@example.com",
      role: role
    )

    [ invitation, invitation.delivery_token ]
  end

  def build_reservation_series(
    shared_resource:,
    user:,
    first_starts_at:,
    first_ends_at:,
    occurrence_count: 4,
    interval_weeks: 1,
    purpose: "Recurring reservation",
    reminder_minutes: nil
  )
    ReservationSeries.new(
      shared_resource: shared_resource,
      user: user,
      first_starts_at: first_starts_at,
      first_ends_at: first_ends_at,
      occurrence_count: occurrence_count,
      interval_weeks: interval_weeks,
      purpose: purpose,
      reminder_minutes: reminder_minutes
    )
  end
end
