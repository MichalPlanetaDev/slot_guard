class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def up
    create_table :audit_events do |t|
      t.references :workspace,
        null: false,
        foreign_key: true
      t.references :actor,
        null: false,
        foreign_key: {
          to_table: :users
        }
      t.references :target_user,
        foreign_key: {
          to_table: :users
        }
      t.string :category, null: false
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :subject_name, null: false
      t.string :actor_name, null: false
      t.string :message, null: false
      t.jsonb :metadata,
        null: false,
        default: {}
      t.datetime :created_at,
        null: false,
        default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :audit_events,
      %i[workspace_id created_at],
      name: "index_audit_events_on_workspace_and_created_at"
    add_index :audit_events,
      %i[workspace_id category created_at],
      name: "index_audit_events_on_workspace_category_and_created_at"
    add_index :audit_events,
      %i[target_user_id created_at],
      name: "index_audit_events_on_target_user_and_created_at"

    add_check_constraint :audit_events,
      "category IN ('reservation', 'scheduling', 'resource', 'administration')",
      name: "audit_events_category"
    add_check_constraint :audit_events,
      "char_length(action) BETWEEN 1 AND 100",
      name: "audit_events_action_length"
    add_check_constraint :audit_events,
      "char_length(subject_type) BETWEEN 1 AND 100",
      name: "audit_events_subject_type_length"
    add_check_constraint :audit_events,
      "char_length(subject_name) BETWEEN 1 AND 254",
      name: "audit_events_subject_name_length"
    add_check_constraint :audit_events,
      "char_length(actor_name) BETWEEN 1 AND 80",
      name: "audit_events_actor_name_length"
    add_check_constraint :audit_events,
      "char_length(message) BETWEEN 1 AND 300",
      name: "audit_events_message_length"
    add_check_constraint :audit_events,
      "jsonb_typeof(metadata) = 'object'",
      name: "audit_events_metadata_object"

    execute <<~SQL
      CREATE FUNCTION prevent_audit_event_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'audit events are immutable'
          USING ERRCODE = '55000';
      END;
      $$;

      CREATE TRIGGER audit_events_immutable
      BEFORE UPDATE OR DELETE ON audit_events
      FOR EACH ROW
      EXECUTE FUNCTION prevent_audit_event_mutation();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS audit_events_immutable
        ON audit_events;
    SQL

    drop_table :audit_events

    execute <<~SQL
      DROP FUNCTION IF EXISTS prevent_audit_event_mutation();
    SQL
  end
end
