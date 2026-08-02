class CommittedIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  self.use_transactional_tests = false

  setup :clear_committed_test_data
  teardown :clear_committed_test_data

  private

  def clear_committed_test_data
    clear_enqueued_jobs
    clear_performed_jobs
    ActionMailer::Base.deliveries.clear

    clear_audit_events
    ReservationReminder.delete_all
    ScheduleBlock.delete_all
    BlackoutPeriod.delete_all
    Reservation.delete_all
    ReservationSeries.delete_all
    AvailabilityWindow.delete_all
    SharedResource.delete_all
    WorkspaceInvitation.delete_all
    Membership.delete_all
    Session.delete_all
    Workspace.delete_all
    User.delete_all
  end

  def clear_audit_events
    return unless ActiveRecord::Base.connection
      .data_source_exists?("audit_events")

    connection = ActiveRecord::Base.connection
    connection.execute(
      "ALTER TABLE audit_events " \
        "DISABLE TRIGGER audit_events_immutable"
    )
    AuditEvent.delete_all
  ensure
    connection&.execute(
      "ALTER TABLE audit_events " \
        "ENABLE TRIGGER audit_events_immutable"
    )
  end
end
