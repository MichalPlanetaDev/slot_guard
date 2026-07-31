require "securerandom"

module UserTestData
  TEST_PASSWORD = "test-password-123"

  def create_user(
    name: "Ada Lovelace",
    email_address: nil,
    password: TEST_PASSWORD
  )
    User.create!(
      name: name,
      email_address: email_address ||
        "user-#{SecureRandom.hex(8)}@example.com",
      password: password,
      password_confirmation: password
    )
  end
end
