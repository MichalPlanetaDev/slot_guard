require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "uses the same response for known and unknown email addresses" do
    user = create_user(email_address: "ada@example.com")

    post passwords_path, params: {
      email_address: user.email_address
    }

    assert_redirected_to new_session_path
    known_notice = flash[:notice]

    post passwords_path, params: {
      email_address: "unknown@example.com"
    }

    assert_redirected_to new_session_path
    assert_equal known_notice, flash[:notice]
  end

  test "resets a password and revokes existing sessions" do
    user = create_user
    user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "Password reset test"
    )
    token = user.password_reset_token

    put password_path(token), params: {
      password: "new-test-password-456",
      password_confirmation: "new-test-password-456"
    }

    assert_redirected_to new_session_path
    assert user.reload.authenticate("new-test-password-456")
    assert_empty user.sessions
  end

  test "rejects an invalid reset token" do
    get edit_password_path("invalid-token")

    assert_redirected_to new_password_path
  end
end
