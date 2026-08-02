require "test_helper"

class BookingPolicyManagementTest <
    ActionDispatch::IntegrationTest
  test "an owner can update workspace policy defaults" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)

    sign_in_as owner

    patch workspace_settings_path, params: {
      workspace: {
        name: workspace.name,
        time_zone: workspace.time_zone,
        minimum_booking_notice_minutes: 90,
        maximum_advance_booking_days: 60,
        maximum_reservation_duration_minutes: 120,
        cancellation_cutoff_minutes: 180
      }
    }

    assert_redirected_to edit_workspace_settings_path

    workspace.reload

    assert_equal 90,
      workspace.minimum_booking_notice_minutes
    assert_equal 60,
      workspace.maximum_advance_booking_days
    assert_equal 120,
      workspace.maximum_reservation_duration_minutes
    assert_equal 180,
      workspace.cancellation_cutoff_minutes
  end

  test "a manager can set and clear one resource override" do
    workspace = create_workspace(
      maximum_reservation_duration_minutes: 180
    )
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    resource = create_shared_resource(workspace: workspace)

    sign_in_as manager

    patch shared_resource_path(resource), params: {
      shared_resource: resource_attributes(
        resource,
        maximum_reservation_duration_minutes: 45
      )
    }

    assert_redirected_to shared_resource_path(resource)
    assert_equal 45,
      resource.reload.maximum_reservation_duration_minutes
    assert_equal 45,
      resource.booking_policy.maximum_reservation_duration_minutes

    patch shared_resource_path(resource), params: {
      shared_resource: resource_attributes(
        resource,
        maximum_reservation_duration_minutes: ""
      )
    }

    assert_redirected_to shared_resource_path(resource)
    assert_nil(
      resource.reload.maximum_reservation_duration_minutes
    )
    assert_equal 180,
      resource.booking_policy.maximum_reservation_duration_minutes
  end

  test "a member cannot change resource policy overrides" do
    workspace = create_workspace
    member = create_user(
      workspace: workspace,
      role: :member
    )
    resource = create_shared_resource(workspace: workspace)

    sign_in_as member

    patch shared_resource_path(resource), params: {
      shared_resource: resource_attributes(
        resource,
        minimum_booking_notice_minutes: 240
      )
    }

    assert_redirected_to shared_resources_path
    assert_nil(
      resource.reload.minimum_booking_notice_minutes
    )
  end

  private

  def resource_attributes(resource, **policy)
    {
      name: resource.name,
      category: resource.category,
      location: resource.location,
      capacity: resource.capacity,
      description: resource.description
    }.merge(policy)
  end
end
