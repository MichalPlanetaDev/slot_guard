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
    assert_includes(
      duplicate.errors[:user_id],
      "has already been taken"
    )
  end

  test "a workspace has only one owner" do
    workspace = create_workspace
    create_user(workspace: workspace)
    second_user = create_user(workspace: nil)

    second_owner = Membership.new(
      workspace: workspace,
      user: second_user,
      role: :owner
    )

    assert_not second_owner.valid?
    assert_includes(
      second_owner.errors[:role],
      "already has an owner"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      Membership.transaction(requires_new: true) do
        second_owner.save!(validate: false)
      end
    end
  end

  test "owners and managers can manage resources" do
    owner = Membership.new(role: :owner)
    manager = Membership.new(role: :manager)
    member = Membership.new(role: :member)

    assert owner.can_manage_resources?
    assert manager.can_manage_resources?
    assert_not member.can_manage_resources?
  end

  test "only owners can manage members" do
    owner = Membership.new(role: :owner)
    manager = Membership.new(role: :manager)
    member = Membership.new(role: :member)

    assert owner.can_manage_members?
    assert_not manager.can_manage_members?
    assert_not member.can_manage_members?
  end

  test "the workspace owner cannot be removed" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    membership = owner.memberships.find_by!(
      workspace: workspace
    )

    assert_not membership.remove_from_workspace(by: owner)
    assert membership.reload.owner?
    assert_includes(
      membership.errors[:base],
      "The workspace owner cannot be removed."
    )
  end

  test "upcoming reservations block member removal" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    membership = member.memberships.find_by!(
      workspace: workspace
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    create_reservation(
      shared_resource: resource,
      user: member,
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_not membership.remove_from_workspace(by: owner)
    assert membership.reload.persisted?
    assert_includes(
      membership.errors[:base],
      "Cancel this member's upcoming reservations before removing them."
    )
  end

  test "a member can be removed after reservations are cancelled" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    membership = member.memberships.find_by!(
      workspace: workspace
    )
    resource = create_shared_resource(workspace: workspace)
    starts_at, ends_at = reservation_times

    create_availability_window(
      shared_resource: resource,
      weekday: starts_at.wday
    )
    reservation = create_reservation(
      shared_resource: resource,
      user: member,
      starts_at: starts_at,
      ends_at: ends_at
    )
    reservation.cancel!(actor: owner)

    assert membership.remove_from_workspace(by: owner)
    assert membership.destroyed?
  end
end
