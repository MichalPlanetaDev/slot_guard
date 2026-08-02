class SharedResource < ApplicationRecord
  belongs_to :workspace

  has_many :availability_windows,
    dependent: :destroy
  has_many :blackout_periods,
    dependent: :restrict_with_error
  has_many :reservations,
    dependent: :restrict_with_error

  enum :category,
    {
      room: "room",
      equipment: "equipment"
    },
    validate: true

  normalizes :name, with: ->(name) { name.strip.squish }
  normalizes :location,
    with: ->(location) { location&.strip&.squish.presence }
  normalizes :description,
    with: ->(description) { description&.strip.presence }

  validates :name,
    presence: true,
    length: { maximum: 100 },
    uniqueness: {
      scope: :workspace_id,
      case_sensitive: false
    }
  validates :location,
    length: { maximum: 120 },
    allow_blank: true
  validates :capacity,
    numericality: {
      only_integer: true,
      greater_than: 0
    },
    allow_nil: true
  validates :description,
    length: { maximum: 1_000 },
    allow_blank: true

  scope :active, -> { where(active: true) }
  scope :archived, -> { where(active: false) }

  def applicable_blackout_periods
    workspace.blackout_periods.applying_to(self)
  end
end
