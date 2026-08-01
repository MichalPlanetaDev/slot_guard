require "uri"

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :reservations, dependent: :restrict_with_error
  has_many :cancelled_reservations,
    class_name: "Reservation",
    foreign_key: :cancelled_by_id,
    dependent: :restrict_with_error,
    inverse_of: :cancelled_by

  normalizes :name, with: ->(name) { name.strip.squish }
  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true, length: { maximum: 80 }
  validates :email_address,
    presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password,
    length: { minimum: 12 },
    if: -> { password.present? }
end
