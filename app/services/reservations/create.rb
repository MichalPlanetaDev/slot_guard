module Reservations
  class Create
    def self.call(reservation)
      new(reservation).call
    end

    def initialize(reservation)
      @reservation = reservation
    end

    def call
      # Validation improves feedback; the constraints close concurrency races.
      Reservation.transaction(requires_new: true) do
        if reservation.save &&
            reservation.reservation_series_id.nil?
          record_creation!
        end
      end

      reservation
    rescue ActiveRecord::StatementInvalid => error
      raise unless PostgresConstraint.exclusion_violation?(error)

      reservation.errors.add(
        :base,
        conflict_message(error)
      )
      reservation
    end

    private

    attr_reader :reservation

    def record_creation!
      AuditEvent.record!(
        workspace: reservation.shared_resource.workspace,
        actor: reservation.user,
        target_user: reservation.user,
        action: "reservation.created",
        category: :reservation,
        subject: reservation,
        subject_name: reservation.purpose,
        message: "Created a reservation for #{reservation.shared_resource.name}.",
        metadata: {
          shared_resource_id: reservation.shared_resource_id,
          starts_at: reservation.starts_at.iso8601,
          ends_at: reservation.ends_at.iso8601
        }
      )
    end

    def conflict_message(error)
      if PostgresConstraint.name(error) ==
          "schedule_blocks_no_overlap" &&
          blackout_conflict?
        Reservation::BLACKOUT_MESSAGE
      else
        Reservation::CONFLICT_MESSAGE
      end
    end

    def blackout_conflict?
      ScheduleBlock.blackout_conflict?(
        workspace: reservation.shared_resource.workspace,
        shared_resource: reservation.shared_resource,
        starts_at: reservation.starts_at,
        ends_at: reservation.ends_at
      )
    end
  end
end
