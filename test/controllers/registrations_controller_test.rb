require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "shows the registration form" do
    get new_registration_path

    assert_response :success
    assert_select "form[action='#{registration_path}']"
    assert_select "input[autocomplete='name']"
    assert_select "input[autocomplete='email']"
    assert_select "input[autocomplete='new-password']", count: 2
  end

  test "creates an account with an owned workspace and starts a session" do
    assert_difference(
      [
        "User.count",
        "Workspace.count",
        "Membership.count"
      ],
      1
    ) do
      post registration_path, params: {
        user: {
          name: "Dorothy Vaughan",
          email_address: "dorothy@example.com",
          password: "correct-horse-battery-staple",
          password_confirmation: "correct-horse-battery-staple"
        }
      }
    end

    user = User.find_by!(email_address: "dorothy@example.com")

    assert_equal "Dorothy Vaughan's workspace", user.workspaces.sole.name
    assert user.memberships.sole.owner?
    assert_redirected_to dashboard_path

    follow_redirect!

    assert_response :success
    assert_select "h1", text: /Welcome, Dorothy/
  end

  test "renders validation errors without creating account data" do
    assert_no_difference(
      [
        "User.count",
        "Workspace.count",
        "Membership.count"
      ]
    ) do
      post registration_path, params: {
        user: {
          name: "",
          email_address: "not-an-email",
          password: "short",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end
end
