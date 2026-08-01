require "test_helper"

class WorkspaceMembershipsControllerTest <
    ActionDispatch::IntegrationTest
  test "an owner can promote a member to manager" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    membership = member.memberships.find_by!(
      workspace: workspace
    )

    sign_in_as owner
    patch workspace_membership_path(membership), params: {
      membership: {
        role: "manager"
      }
    }

    assert_redirected_to workspace_team_path
    assert membership.reload.manager?
  end

  test "the owner role cannot be changed" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    membership = owner.memberships.find_by!(
      workspace: workspace
    )

    sign_in_as owner
    patch workspace_membership_path(membership), params: {
      membership: {
        role: "member"
      }
    }

    assert_redirected_to workspace_team_path
    assert membership.reload.owner?
  end

  test "a manager cannot change another membership" do
    workspace = create_workspace
    manager = create_user(
      workspace: workspace,
      role: :manager
    )
    member = create_user(
      workspace: workspace,
      role: :member
    )
    membership = member.memberships.find_by!(
      workspace: workspace
    )

    sign_in_as manager
    patch workspace_membership_path(membership), params: {
      membership: {
        role: "manager"
      }
    }

    assert_redirected_to workspace_team_path
    assert membership.reload.member?
  end

  test "an owner can remove a member without upcoming reservations" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)
    member = create_user(
      workspace: workspace,
      role: :member
    )
    membership = member.memberships.find_by!(
      workspace: workspace
    )

    sign_in_as owner

    assert_difference("Membership.count", -1) do
      delete workspace_membership_path(membership)
    end

    assert_redirected_to workspace_team_path
  end
end
