require "digest"
require "securerandom"
require "uri"

class WorkspaceInvitation < ApplicationRecord
  DELIVERY_WINDOW = 7.days
  TOKEN_BYTES = 32

  belongs_to :workspace
  belongs_to :invited_by,
    class_name: "User",
    inverse_of: :sent_workspace_invitations
  belongs_to :accepted_by,
    class_name: "User",
    inverse_of: :accepted_workspace_invitations,
    optional: true
  belongs_to :revoked_by,
    class_name: "User",
    inverse_of: :revoked_workspace_invitations,
    optional: true

  enum :role,
    {
      member: 0,
      manager: 1
    },
    default: :member,
    validate: true

  normalizes :email_address,
    with: ->(email_address) { email_address.strip.downcase }

  validates :email_address,
    presence: true,
    length: {
      maximum: 254
    },
    format: {
      with: URI::MailTo::EMAIL_REGEXP
    },
    uniqueness: {
      scope: :workspace_id,
      case_sensitive: false,
      conditions: -> {
        where(
          accepted_at: nil,
          revoked_at: nil
        )
      }
    },
    if: :pending?
  validates :token_digest,
    presence: true,
    uniqueness: true,
    if: :pending?
  validates :expires_at, presence: true

  validate :inviter_owns_workspace
  validate :email_is_not_already_a_member,
    if: :pending?
  validate :terminal_state_is_consistent

  before_validation :ensure_delivery_token,
    on: :create

  scope :pending, -> {
    where(
      accepted_at: nil,
      revoked_at: nil
    )
  }
  scope :recent_first, -> {
    order(created_at: :desc, id: :desc)
  }

  attr_reader :delivery_token

  def self.find_by_delivery_token(token)
    return if token.blank?

    find_by(
      token_digest: Digest::SHA256.hexdigest(token)
    )
  end

  def pending?
    accepted_at.nil? && revoked_at.nil?
  end

  def accepted?
    accepted_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    pending? &&
      expires_at.present? &&
      expires_at <= Time.current
  end

  def rotate_delivery_token
    unless new_record? || pending?
      raise ArgumentError,
        "Only pending invitations can receive a new token."
    end

    # The raw token is transient; only its digest reaches the database.
    @delivery_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    self.token_digest =
      Digest::SHA256.hexdigest(@delivery_token)
    self.expires_at = DELIVERY_WINDOW.from_now
  end

  def accept_by(user)
    with_lock do
      errors.clear

      return reject_acceptance(
        "This invitation has already been accepted or revoked."
      ) unless pending?

      return reject_acceptance(
        "This invitation has expired. Ask the workspace owner to resend it."
      ) if expired?

      unless email_address.casecmp?(user.email_address)
        return reject_acceptance(
          "Sign in with #{email_address} to accept this invitation."
        )
      end

      membership = workspace.memberships.create!(
        user: user,
        role: role
      )

      update!(
        token_digest: nil,
        accepted_at: Time.current,
        accepted_by: user
      )

      membership
    end
  rescue ActiveRecord::RecordNotUnique
    errors.add(
      :base,
      "This account already belongs to the workspace."
    )
    nil
  end

  def revoke_by(user)
    with_lock do
      errors.clear

      unless pending?
        errors.add(
          :base,
          "Only a pending invitation can be revoked."
        )
        return false
      end

      revoking_membership = workspace.memberships.find_by(
        user_id: user.id
      )

      unless revoking_membership&.owner?
        errors.add(
          :base,
          "Only the workspace owner can revoke invitations."
        )
        return false
      end

      update!(
        token_digest: nil,
        revoked_at: Time.current,
        revoked_by: user
      )
    end
  end

  private

  def ensure_delivery_token
    rotate_delivery_token if token_digest.blank?
  end

  def inviter_owns_workspace
    return unless workspace&.persisted? && invited_by&.persisted?

    inviter_membership = workspace.memberships.find_by(
      user_id: invited_by.id
    )
    return if inviter_membership&.owner?

    errors.add(
      :invited_by,
      "must own the workspace"
    )
  end

  def email_is_not_already_a_member
    return if email_address.blank? || !workspace&.persisted?

    existing_member = workspace.users.where(
      "lower(users.email_address) = ?",
      email_address.downcase
    ).exists?

    if existing_member
      errors.add(
        :email_address,
        "already belongs to this workspace"
      )
    end
  end

  def terminal_state_is_consistent
    pending_state =
      accepted_at.nil? &&
      accepted_by_id.nil? &&
      revoked_at.nil? &&
      revoked_by_id.nil? &&
      token_digest.present?

    accepted_state =
      accepted_at.present? &&
      accepted_by_id.present? &&
      revoked_at.nil? &&
      revoked_by_id.nil? &&
      token_digest.nil?

    revoked_state =
      accepted_at.nil? &&
      accepted_by_id.nil? &&
      revoked_at.present? &&
      revoked_by_id.present? &&
      token_digest.nil?

    return if pending_state || accepted_state || revoked_state

    errors.add(
      :base,
      "Invitation state is inconsistent."
    )
  end

  def reject_acceptance(message)
    errors.add(:base, message)
    nil
  end
end
