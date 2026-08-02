class Membership < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  enum :role,
    {
      member: 0,
      manager: 1,
      owner: 2
    },
    default: :member,
    validate: true

  validates :user_id,
    uniqueness: {
      scope: :workspace_id
    }
  validates :role,
    uniqueness: {
      scope: :workspace_id,
      message: "already has an owner"
    },
    if: :owner?

  def can_manage_resources?
    owner? || manager?
  end

  def can_manage_members?
    owner?
  end

  def change_role_to(role, by:)
    with_lock do
      errors.clear

      unless workspace_owner?(by)
        errors.add(
          :base,
          "Only the workspace owner can change member roles."
        )
        return false
      end

      if owner?
        errors.add(
          :base,
          "The workspace owner role cannot be changed."
        )
        return false
      end

      unless %w[member manager].include?(role.to_s)
        errors.add(
          :role,
          "must be member or manager"
        )
        return false
      end

      previous_role = self.role
      return false unless update(role: role)

      AuditEvent.record!(
        workspace: workspace,
        actor: by,
        target_user: user,
        action: "membership.role_changed",
        category: :administration,
        subject: self,
        subject_name: user.name,
        message: "Changed #{user.name}'s role from #{previous_role} to #{self.role}.",
        metadata: {
          previous_role: previous_role,
          role: self.role
        }
      )

      true
    end
  end

  def remove_from_workspace(by:)
    with_lock do
      errors.clear

      unless workspace_owner?(by)
        errors.add(
          :base,
          "Only the workspace owner can remove members."
        )
        return false
      end

      if owner?
        errors.add(
          :base,
          "The workspace owner cannot be removed."
        )
        return false
      end

      # Upcoming reservations remain attributable to an active workspace member.
      if workspace.reservations.upcoming.where(user_id: user_id).exists?
        errors.add(
          :base,
          "Cancel this member's upcoming reservations before removing them."
        )
        return false
      end

      removed_user = user
      removed_role = role

      destroy!

      AuditEvent.record!(
        workspace: workspace,
        actor: by,
        target_user: removed_user,
        action: "membership.removed",
        category: :administration,
        subject: self,
        subject_name: removed_user.name,
        message: "Removed #{removed_user.name} from the workspace.",
        metadata: {
          role: removed_role
        }
      )

      true
    end
  end

  private

  def workspace_owner?(actor)
    workspace.memberships.exists?(
      user_id: actor.id,
      role: self.class.roles.fetch("owner")
    )
  end
end
