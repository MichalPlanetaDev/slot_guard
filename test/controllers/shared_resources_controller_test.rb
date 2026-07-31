require "test_helper"

class SharedResourcesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get shared_resources_path

    assert_redirected_to new_session_path
  end

  test "lists only resources from the current workspace" do
    workspace = create_workspace(name: "Engineering Lab")
    user = create_user(workspace: workspace)
    visible = create_shared_resource(
      workspace: workspace,
      name: "Studio A"
    )
    hidden = create_shared_resource(
      workspace: create_workspace(name: "Media Lab"),
      name: "Camera 2",
      category: :equipment
    )

    sign_in_as user
    get shared_resources_path

    assert_response :success
    assert_select "h2", text: visible.name
    assert_select "body", text: /#{visible.name}/
    assert_select "body", text: /#{Regexp.escape(hidden.name)}/, count: 0
  end

  test "an owner can create a resource" do
    workspace = create_workspace
    user = create_user(workspace: workspace)

    sign_in_as user

    assert_difference("workspace.shared_resources.count", 1) do
      post shared_resources_path, params: {
        shared_resource: {
          name: "Workshop projector",
          category: "equipment",
          location: "Cabinet 4",
          capacity: 1,
          description: "HDMI and USB-C inputs"
        }
      }
    end

    shared_resource = workspace.shared_resources.order(:id).last

    assert_redirected_to shared_resource_path(shared_resource)
    assert_equal "Workshop projector", shared_resource.name
  end

  test "invalid resource data is rendered without persistence" do
    workspace = create_workspace
    user = create_user(workspace: workspace)

    sign_in_as user

    assert_no_difference("SharedResource.count") do
      post shared_resources_path, params: {
        shared_resource: {
          name: "",
          category: "",
          capacity: 0
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end

  test "a member can view resources but cannot change them" do
    workspace = create_workspace
    user = create_user(
      workspace: workspace,
      role: :member
    )
    shared_resource = create_shared_resource(
      workspace: workspace
    )

    sign_in_as user
    get shared_resource_path(shared_resource)

    assert_response :success
    assert_select "a[href='#{edit_shared_resource_path(shared_resource)}']", count: 0

    assert_no_difference("SharedResource.count") do
      post shared_resources_path, params: {
        shared_resource: {
          name: "Unauthorized resource",
          category: "room"
        }
      }
    end

    assert_redirected_to shared_resources_path
  end

  test "a resource from another workspace is not addressable" do
    user = create_user
    other_resource = create_shared_resource(
      workspace: create_workspace
    )

    sign_in_as user

    get shared_resource_path(other_resource)

    assert_response :not_found
  end

  test "an owner can archive and restore a resource" do
    workspace = create_workspace
    user = create_user(workspace: workspace)
    shared_resource = create_shared_resource(
      workspace: workspace
    )

    sign_in_as user

    patch archive_shared_resource_path(shared_resource)

    assert_redirected_to shared_resources_path(status: "archived")
    assert_not shared_resource.reload.active?

    patch restore_shared_resource_path(shared_resource)

    assert_redirected_to shared_resource_path(shared_resource)
    assert shared_resource.reload.active?
  end
end
