require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "prevents duplicate workspace membership" do
    workspace = create_workspace
    user = create_user(workspace: workspace)

    duplicate = Membership.new(
      workspace: workspace,
      user: user,
      role: :member
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "owners and managers can manage resources" do
    owner = Membership.new(role: :owner)
    manager = Membership.new(role: :manager)
    member = Membership.new(role: :member)

    assert owner.can_manage_resources?
    assert manager.can_manage_resources?
    assert_not member.can_manage_resources?
  end
end
