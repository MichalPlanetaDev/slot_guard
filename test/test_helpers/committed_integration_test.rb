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

    ReservationReminder.delete_all
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
end
