require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  test "exposes the authenticated user from the current session" do
    user = create_user

    Current.session = Session.new(user: user)

    assert_equal user, Current.user
  ensure
    Current.reset
  end
end
