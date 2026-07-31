module SessionTestHelper
  def sign_in_as(user, password: UserTestData::TEST_PASSWORD)
    post session_path, params: {
      session: {
        email_address: user.email_address,
        password: password
      }
    }
  end
end
