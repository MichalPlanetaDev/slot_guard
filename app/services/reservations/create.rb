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
        reservation.save
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
