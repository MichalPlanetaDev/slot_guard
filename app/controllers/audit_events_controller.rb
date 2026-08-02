class AuditEventsController < WorkspaceController
  def index
    @audit_events = AuditEvent
      .visible_to(current_membership)
      .includes(:actor)
      .recent_first
      .limit(100)
  end
end
