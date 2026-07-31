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
    uniqueness: { scope: :workspace_id }

  def can_manage_resources?
    owner? || manager?
  end
end
