require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes names and email addresses" do
    user = create_user(
      name: "  Katherine   Johnson  ",
      email_address: "  KATHERINE@EXAMPLE.COM ",
      password: "correct-horse-battery-staple"
    )

    assert_equal "Katherine Johnson", user.name
    assert_equal "katherine@example.com", user.email_address
  end

  test "requires a valid email address" do
    user = User.new(
      name: "New User",
      email_address: "not-an-email",
      password: "correct-horse-battery-staple"
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "requires at least twelve password characters" do
    user = User.new(
      name: "New User",
      email_address: "new@example.com",
      password: "too-short"
    )

    assert_not user.valid?

    assert_includes(
      user.errors[:password],
      "is too short (minimum is 12 characters)"
    )
  end

  test "treats email addresses as case-insensitively unique" do
    existing_user = create_user(email_address: "ada@example.com")

    duplicate = User.new(
      name: "Duplicate User",
      email_address: existing_user.email_address.upcase,
      password: "correct-horse-battery-staple"
    )

    assert_not duplicate.valid?

    assert_includes(
      duplicate.errors[:email_address],
      "has already been taken"
    )
  end
end
