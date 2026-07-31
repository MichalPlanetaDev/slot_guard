require "uri"

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships

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
