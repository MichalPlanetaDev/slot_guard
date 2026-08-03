module Demo
  class Reset
    OWNER_EMAIL = ENV.fetch(
      "DEMO_EMAIL",
      "demo@slotguard.app"
    )
    OWNER_PASSWORD = ENV.fetch(
      "DEMO_PASSWORD",
      "SlotGuard-demo-2026!"
    )
    WORKSPACE_NAME = "SlotGuard Demo".freeze
    TIME_ZONE = "Europe/Warsaw".freeze

    class Disabled < StandardError
    end

    def self.call(force: false)
      new(force: force).call
    end

    def initialize(force:)
      @force = force
    end

    def call
      raise Disabled unless enabled?

      ApplicationRecord.transaction do
        owner = ensure_user(
          email_address: OWNER_EMAIL,
          name: "Demo Owner"
        )
        manager = ensure_user(
          email_address: "manager@slotguard.app",
          name: "Demo Manager"
        )
        member = ensure_user(
          email_address: "member@slotguard.app",
          name: "Demo Member"
        )
        workspace = ensure_workspace(owner)

        clear_workspace(workspace)
        restore_memberships(
          workspace,
          owner: owner,
          manager: manager,
          member: member
        )
        resources = restore_resources(workspace)
        restore_reservations(
          workspace,
          resources: resources,
          owner: owner,
          manager: manager,
          member: member
        )
        restore_blackout(
          workspace,
          resource: resources.fetch(:studio),
          owner: owner
        )

        workspace
      end
    end

    private

    attr_reader :force

    def enabled?
      force || ENV["DEMO_MODE"] == "true"
    end

    def ensure_user(email_address:, name:)
      user = User.find_or_initialize_by(
        email_address: email_address
      )
      user.assign_attributes(
        name: name,
        password: OWNER_PASSWORD,
        password_confirmation: OWNER_PASSWORD
      )
      user.save!
      user
    end

    def ensure_workspace(owner)
      workspace = owner.memberships
        .includes(:workspace)
        .find_by(role: :owner)
        &.workspace
      workspace ||= Workspace.find_or_initialize_by(
        name: WORKSPACE_NAME
      )

      workspace.update!(
        name: WORKSPACE_NAME,
        time_zone: TIME_ZONE,
        minimum_booking_notice_minutes: 0,
        maximum_advance_booking_days: 365,
        maximum_reservation_duration_minutes: 720,
        cancellation_cutoff_minutes: 0
      )

      Membership.find_or_create_by!(
        workspace: workspace,
        user: owner
      ).update!(role: :owner)

      workspace
    end

    def clear_workspace(workspace)
      resource_ids = workspace.shared_resources.ids
      reservation_ids = Reservation
        .where(shared_resource_id: resource_ids)
        .ids

      ReservationReminder
        .where(reservation_id: reservation_ids)
        .delete_all
      ScheduleBlock
        .where(workspace_id: workspace.id)
        .delete_all
      Reservation
        .where(id: reservation_ids)
        .delete_all
      ReservationSeries
        .where(shared_resource_id: resource_ids)
        .delete_all
      BlackoutPeriod
        .where(workspace_id: workspace.id)
        .delete_all
      AvailabilityWindow
        .where(shared_resource_id: resource_ids)
        .delete_all
      WorkspaceInvitation
        .where(workspace_id: workspace.id)
        .delete_all
      SharedResource
        .where(id: resource_ids)
        .delete_all
    end

    def restore_memberships(
      workspace,
      owner:,
      manager:,
      member:
    )
      expected_user_ids = [
        owner.id,
        manager.id,
        member.id
      ]

      workspace.memberships
        .where.not(user_id: expected_user_ids)
        .delete_all

      {
        owner => :owner,
        manager => :manager,
        member => :member
      }.each do |user, role|
        membership = Membership.find_or_initialize_by(
          workspace: workspace,
          user: user
        )
        membership.role = role
        membership.save!
      end
    end

    def restore_resources(workspace)
      studio = create_resource(
        workspace,
        name: "Studio A",
        category: :room,
        location: "First floor",
        capacity: 8,
        description: "A quiet production room with flexible seating."
      )
      camera = create_resource(
        workspace,
        name: "Camera Kit",
        category: :equipment,
        location: "Equipment desk",
        description: "Camera body, two lenses, tripod, and audio recorder.",
        maximum_reservation_duration_minutes: 240
      )
      meeting_room = create_resource(
        workspace,
        name: "Meeting Room",
        category: :room,
        location: "Second floor",
        capacity: 10,
        description: "A team room with a display and whiteboard."
      )

      [ studio, camera, meeting_room ].each do |resource|
        (0..6).each do |weekday|
          AvailabilityWindow.create!(
            shared_resource: resource,
            weekday: weekday,
            starts_minute: 8 * 60,
            ends_minute: 20 * 60
          )
        end
      end

      {
        studio: studio,
        camera: camera,
        meeting_room: meeting_room
      }
    end

    def create_resource(workspace, **attributes)
      workspace.shared_resources.create!(
        {
          active: true
        }.merge(attributes)
      )
    end

    def restore_reservations(
      workspace,
      resources:,
      owner:,
      manager:,
      member:
    )
      tomorrow = workspace.local_time(Time.current)
        .to_date
        .next_day

      create_reservation(
        workspace,
        resource: resources.fetch(:studio),
        user: member,
        date: tomorrow,
        starts_minute: 9 * 60,
        ends_minute: 10 * 60 + 30,
        purpose: "Product photography"
      )
      create_reservation(
        workspace,
        resource: resources.fetch(:camera),
        user: manager,
        date: tomorrow,
        starts_minute: 11 * 60,
        ends_minute: 13 * 60,
        purpose: "Customer interview"
      )
      create_reservation(
        workspace,
        resource: resources.fetch(:meeting_room),
        user: owner,
        date: tomorrow,
        starts_minute: 15 * 60,
        ends_minute: 16 * 60,
        purpose: "Weekly planning"
      )
    end

    def create_reservation(
      workspace,
      resource:,
      user:,
      date:,
      starts_minute:,
      ends_minute:,
      purpose:
    )
      reservation = Reservation.new(
        shared_resource: resource,
        user: user,
        starts_at: workspace.local_time_at(
          date,
          starts_minute
        ),
        ends_at: workspace.local_time_at(
          date,
          ends_minute
        ),
        purpose: purpose,
        reminder_minutes: nil
      )

      Reservations::Create.call(reservation)
      reservation.save! unless reservation.persisted?
      reservation
    end

    def restore_blackout(workspace, resource:, owner:)
      date = workspace.local_time(Time.current)
        .to_date
        .next_day

      blackout = BlackoutPeriod.new(
        workspace: workspace,
        shared_resource: resource,
        created_by: owner,
        reason: "Lighting maintenance",
        all_day: false,
        starts_at: workspace.local_time_at(
          date,
          17 * 60
        ),
        ends_at: workspace.local_time_at(
          date,
          18 * 60
        )
      )

      BlackoutPeriods::Create.call(blackout)
      blackout.save! unless blackout.persisted?
      blackout
    end
  end
end
