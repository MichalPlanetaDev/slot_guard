require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get dashboard_path

    assert_redirected_to new_session_path
  end

  test "shows workspace resources and upcoming reservations" do
    workspace = create_workspace(name: "Engineering Lab")
    user = create_user(
      name: "Ada Lovelace",
      workspace: workspace
    )

    room = create_shared_resource(
      workspace: workspace,
      name: "Studio A",
      category: :room
    )
    create_shared_resource(
      workspace: workspace,
      name: "Camera 2",
      category: :equipment
    )
    starts_at, ends_at = reservation_times
    create_availability_window(
      shared_resource: room,
      weekday: starts_at.wday
    )
    create_reservation(
      shared_resource: room,
      user: user,
      starts_at: starts_at,
      ends_at: ends_at,
      purpose: "Prototype review"
    )

    sign_in_as user
    get dashboard_path

    assert_response :success
    assert_select "h1", text: /Welcome, Ada/
    assert_select "body", text: /Engineering Lab/
    assert_select "body", text: /Prototype review/
    assert_select "a[href='#{shared_resources_path}']"
    assert_select "a[href='#{reservations_path}']"
    assert_select "a[href='#{new_reservation_path}']"
  end
end
