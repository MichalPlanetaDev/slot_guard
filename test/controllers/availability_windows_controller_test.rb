require "test_helper"

class AvailabilityWindowsControllerTest < ActionDispatch::IntegrationTest
  test "an owner can add availability" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)

    sign_in_as owner

    assert_difference("AvailabilityWindow.count", 1) do
      post shared_resource_availability_windows_path(
        shared_resource
      ), params: {
        availability_window: {
          weekday: 1,
          starts_minute: 9 * 60,
          ends_minute: 17 * 60
        }
      }
    end

    assert_redirected_to shared_resource_path(shared_resource)
  end

  test "an overlapping window renders an error" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)

    create_availability_window(
      shared_resource: shared_resource,
      weekday: 1,
      starts_minute: 9 * 60,
      ends_minute: 12 * 60
    )

    sign_in_as owner

    assert_no_difference("AvailabilityWindow.count") do
      post shared_resource_availability_windows_path(
        shared_resource
      ), params: {
        availability_window: {
          weekday: 1,
          starts_minute: 11 * 60,
          ends_minute: 13 * 60
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']",
      text: /overlaps an existing window/
  end

  test "a member cannot change availability" do
    workspace = create_workspace
    member = create_user(
      workspace: workspace,
      role: :member
    )
    shared_resource = create_shared_resource(workspace: workspace)

    sign_in_as member

    assert_no_difference("AvailabilityWindow.count") do
      post shared_resource_availability_windows_path(
        shared_resource
      ), params: {
        availability_window: {
          weekday: 1,
          starts_minute: 9 * 60,
          ends_minute: 17 * 60
        }
      }
    end

    assert_redirected_to shared_resources_path
  end

  test "an owner can remove availability" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    shared_resource = create_shared_resource(workspace: workspace)
    window = create_availability_window(
      shared_resource: shared_resource,
      weekday: 1
    )

    sign_in_as owner

    assert_difference("AvailabilityWindow.count", -1) do
      delete shared_resource_availability_window_path(
        shared_resource,
        window
      )
    end

    assert_redirected_to shared_resource_path(shared_resource)
  end
end
