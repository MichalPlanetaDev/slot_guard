module BlackoutPeriods
  class Create
    def self.call(blackout_period)
      new(blackout_period).call
    end

    def initialize(blackout_period)
      @blackout_period = blackout_period
    end

    def call
      BlackoutPeriod.transaction(requires_new: true) do
        blackout_period.save
      end

      blackout_period
    rescue ActiveRecord::StatementInvalid => error
      raise unless schedule_conflict?(error)

      blackout_period.errors.add(
        :base,
        conflict_message
      )
      blackout_period
    end

    private

    attr_reader :blackout_period

    def schedule_conflict?(error)
      PostgresConstraint.exclusion_violation?(error) &&
        PostgresConstraint.name(error) ==
          "schedule_blocks_no_overlap"
    end

    def conflict_message
      if ScheduleBlock.reservation_conflict?(
        workspace: blackout_period.workspace,
        shared_resource: blackout_period.shared_resource,
        starts_at: blackout_period.starts_at,
        ends_at: blackout_period.ends_at
      )
        BlackoutPeriod::RESERVATION_CONFLICT_MESSAGE
      else
        BlackoutPeriod::OVERLAP_MESSAGE
      end
    end
  end
end
