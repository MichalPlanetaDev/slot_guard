class Current < ActiveSupport::CurrentAttributes
  attribute :session, :membership, :workspace

  delegate :user, to: :session, allow_nil: true
end
