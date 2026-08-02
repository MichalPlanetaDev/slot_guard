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
        record_creation! if blackout_period.save
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

    def record_creation!
      AuditEvent.record!(
        workspace: blackout_period.workspace,
        actor: blackout_period.created_by,
        action: "blackout.created",
        category: :scheduling,
        subject: blackout_period,
        subject_name: blackout_period.reason,
        message: "Added a blackout for #{scope_description}.",
        metadata: {
          shared_resource_id: blackout_period.shared_resource_id,
          all_day: blackout_period.all_day?,
          starts_at: blackout_period.starts_at.iso8601,
          ends_at: blackout_period.ends_at.iso8601
        }
      )
    end

    def scope_description
      if blackout_period.workspace_wide?
        "the entire workspace"
      else
        blackout_period.shared_resource.name
      end
    end

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
