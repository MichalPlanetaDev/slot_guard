class Workspace < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :shared_resources, dependent: :restrict_with_error
  has_many :reservations, through: :shared_resources

  normalizes :name, with: ->(name) { name.strip.squish }

  validates :name,
    presence: true,
    length: { maximum: 100 }
end
