module Reservations
  class Create
    def self.call(reservation)
      new(reservation).call
    end

    def initialize(reservation)
      @reservation = reservation
    end

    def call
      # Validation improves feedback; the constraint closes concurrency races.
      Reservation.transaction(requires_new: true) do
        reservation.save
      end

      reservation
    rescue ActiveRecord::StatementInvalid => error
      raise unless exclusion_violation?(error)

      reservation.errors.add(
        :base,
        Reservation::CONFLICT_MESSAGE
      )
      reservation
    end

    private

    attr_reader :reservation

    def exclusion_violation?(error)
      cause = error.cause

      return true if cause.is_a?(PG::ExclusionViolation)
      return false unless cause.respond_to?(:result)

      cause.result.error_field(
        PG::Result::PG_DIAG_SQLSTATE
      ) == "23P01"
    end
  end
end
