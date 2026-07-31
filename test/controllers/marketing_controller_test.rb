require "test_helper"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  test "shows the public landing page" do
    get root_path

    assert_response :success
    assert_select "h1", text: /Reserve shared equipment/
    assert_select "a[href='#{new_registration_path}']"
    assert_select "link[rel='icon'][href='/favicon.svg']"
  end

  test "redirects an authenticated user to the dashboard" do
    user = create_user
    sign_in_as user

    get root_path

    assert_redirected_to dashboard_path
  end
end
