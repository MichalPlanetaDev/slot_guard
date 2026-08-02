class AuditEvent < ApplicationRecord
  CATEGORIES = {
    reservation: "reservation",
    scheduling: "scheduling",
    resource: "resource",
    administration: "administration"
  }.freeze
  ACTIONS = %w[
    reservation.created
    reservation.cancelled
    reservation_series.created
    reservation_series.cancelled
    blackout.created
    blackout.removed
    resource.created
    resource.updated
    resource.archived
    resource.restored
    workspace.updated
    invitation.sent
    invitation.accepted
    invitation.revoked
    membership.role_changed
    membership.removed
  ].freeze
  MANAGER_CATEGORIES = %w[
    reservation
    scheduling
    resource
  ].freeze

  belongs_to :workspace
  belongs_to :actor,
    class_name: "User",
    inverse_of: :authored_audit_events
  belongs_to :target_user,
    class_name: "User",
    optional: true,
    inverse_of: :targeted_audit_events

  enum :category,
    CATEGORIES,
    validate: true

  validates :action,
    presence: true,
    inclusion: {
      in: ACTIONS
    },
    length: {
      maximum: 100
    }
  validates :subject_type,
    presence: true,
    length: {
      maximum: 100
    }
  validates :subject_name,
    presence: true,
    length: {
      maximum: 254
    }
  validates :subject_id,
    presence: true
  validates :actor_name,
    presence: true,
    length: {
      maximum: 80
    }
  validates :message,
    presence: true,
    length: {
      maximum: 300
    }

  validate :actor_belongs_to_workspace
  validate :metadata_is_object

  scope :recent_first, -> {
    order(created_at: :desc, id: :desc)
  }

  class << self
    def record!(
      workspace:,
      actor:,
      action:,
      category:,
      subject:,
      subject_name:,
      message:,
      target_user: nil,
      metadata: {}
    )
      create!(
        workspace: workspace,
        actor: actor,
        target_user: target_user,
        action: action,
        category: category,
        subject_type: subject.class.base_class.name,
        subject_id: subject.id,
        subject_name: subject_name,
        actor_name: actor.name,
        message: message,
        metadata: metadata.deep_stringify_keys
      )
    end

    def visible_to(membership)
      return none unless membership

      events = where(
        workspace_id: membership.workspace_id
      )

      if membership.owner?
        events
      elsif membership.manager?
        events.where(category: MANAGER_CATEGORIES)
      else
        events.where(
          category: CATEGORIES.fetch(:reservation),
          target_user_id: membership.user_id
        )
      end
    end
  end

  def readonly?
    persisted?
  end

  private

  def actor_belongs_to_workspace
    return unless actor&.persisted? &&
      workspace&.persisted?
    return if workspace.memberships.exists?(
      user_id: actor_id
    )

    errors.add(
      :actor,
      "must belong to the workspace"
    )
  end

  def metadata_is_object
    return if metadata.is_a?(Hash)

    errors.add(
      :metadata,
      "must be an object"
    )
  end
end
