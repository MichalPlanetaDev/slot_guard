require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signs in with normalized credentials" do
    create_user(email_address: "ada@example.com")

    post session_path, params: {
      session: {
        email_address: "  ADA@EXAMPLE.COM ",
        password: UserTestData::TEST_PASSWORD
      }
    }

    assert_redirected_to dashboard_path
  end

  test "rejects invalid credentials without identifying the failed field" do
    user = create_user

    post session_path, params: {
      session: {
        email_address: user.email_address,
        password: "incorrect-password"
      }
    }

    assert_redirected_to new_session_path

    assert_equal(
      "The email address or password is incorrect.",
      flash[:alert]
    )
  end

  test "signs out the current session" do
    user = create_user
    sign_in_as user

    delete session_path

    assert_redirected_to root_path
  end
end
