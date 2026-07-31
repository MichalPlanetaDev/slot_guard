require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get dashboard_path

    assert_redirected_to new_session_path
  end

  test "shows the authenticated workspace" do
    user = create_user(name: "Ada Lovelace")
    sign_in_as user

    get dashboard_path

    assert_response :success
    assert_select "h1", text: /Welcome, Ada/
    assert_select "form[action='#{session_path}']"
  end
end
