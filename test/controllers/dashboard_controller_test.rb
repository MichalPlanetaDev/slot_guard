require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get dashboard_path

    assert_redirected_to new_session_path
  end

  test "shows workspace resource totals" do
    workspace = create_workspace(name: "Engineering Lab")
    user = create_user(
      name: "Ada Lovelace",
      workspace: workspace
    )

    create_shared_resource(
      workspace: workspace,
      name: "Studio A",
      category: :room
    )
    create_shared_resource(
      workspace: workspace,
      name: "Camera 2",
      category: :equipment
    )

    sign_in_as user
    get dashboard_path

    assert_response :success
    assert_select "h1", text: /Welcome, Ada/
    assert_select "body", text: /Engineering Lab/
    assert_select "a[href='#{shared_resources_path}']"
    assert_select "a[href='#{new_shared_resource_path}']"
  end
end
