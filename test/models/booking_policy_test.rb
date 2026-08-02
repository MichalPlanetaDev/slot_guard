require "test_helper"

class BookingPolicyTest < ActiveSupport::TestCase
  test "a resource inherits each workspace setting independently" do
    workspace = create_workspace(
      minimum_booking_notice_minutes: 120,
      maximum_advance_booking_days: 45,
      maximum_reservation_duration_minutes: 180,
      cancellation_cutoff_minutes: 240
    )
    resource = create_shared_resource(
      workspace: workspace,
      maximum_reservation_duration_minutes: 60
    )
    policy = resource.booking_policy

    assert_equal 120,
      policy.minimum_booking_notice_minutes
    assert_equal 45,
      policy.maximum_advance_booking_days
    assert_equal 60,
      policy.maximum_reservation_duration_minutes
    assert_equal 240,
      policy.cancellation_cutoff_minutes

    assert policy.inherited?(
      :minimum_booking_notice_minutes
    )
    assert_not policy.inherited?(
      :maximum_reservation_duration_minutes
    )
  end

  test "workspace policy values stay within supported ranges" do
    workspace = build_workspace(
      minimum_booking_notice_minutes: -1
    )

    assert_not workspace.valid?
    assert_includes(
      workspace.errors[:minimum_booking_notice_minutes],
      "must be greater than or equal to 0"
    )
  end

  test "resource overrides stay within supported ranges" do
    resource = SharedResource.new(
      workspace: create_workspace,
      name: "Policy room",
      category: :room,
      maximum_advance_booking_days: 0
    )

    assert_not resource.valid?
    assert_includes(
      resource.errors[:maximum_advance_booking_days],
      "must be greater than or equal to 1"
    )
  end

  test "database constraints reject invalid workspace policy values" do
    workspace = create_workspace

    assert_raises(ActiveRecord::StatementInvalid) do
      Workspace.transaction(requires_new: true) do
        workspace.update_columns(
          cancellation_cutoff_minutes: -1
        )
      end
    end
  end

  private

  def build_workspace(**attributes)
    Workspace.new(
      {
        name: "Policy workspace"
      }.merge(attributes)
    )
  end
end
