class CreateWorkspaceInvitations < ActiveRecord::Migration[8.1]
  def change
    # Ownership is singular even if a future code path bypasses controller rules.
    add_index :memberships,
      :workspace_id,
      unique: true,
      where: "role = 2",
      name: "index_memberships_on_unique_workspace_owner"

    create_table :workspace_invitations do |t|
      t.references :workspace,
        null: false,
        foreign_key: true
      t.references :invited_by,
        null: false,
        foreign_key: {
          to_table: :users
        }
      t.string :email_address, null: false
      t.integer :role, null: false, default: 0
      t.string :token_digest
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.references :accepted_by,
        foreign_key: {
          to_table: :users
        }
      t.datetime :revoked_at
      t.references :revoked_by,
        foreign_key: {
          to_table: :users
        }

      t.timestamps
    end

    add_index :workspace_invitations,
      :token_digest,
      unique: true,
      where: "token_digest IS NOT NULL"

    add_index :workspace_invitations,
      "workspace_id, lower(email_address)",
      unique: true,
      where: "accepted_at IS NULL AND revoked_at IS NULL",
      name: "index_pending_invitations_on_workspace_and_email"

    add_index :workspace_invitations,
      %i[workspace_id created_at],
      name: "index_workspace_invitations_on_workspace_and_created_at"

    add_check_constraint :workspace_invitations,
      "role IN (0, 1)",
      name: "workspace_invitations_role_value"

    add_check_constraint :workspace_invitations,
      "char_length(btrim(email_address)) BETWEEN 3 AND 254",
      name: "workspace_invitations_email_length"

    add_check_constraint :workspace_invitations,
      "expires_at > created_at",
      name: "workspace_invitations_positive_expiration"

    terminal_state = <<~SQL.squish
      (
        accepted_at IS NULL AND
        accepted_by_id IS NULL AND
        revoked_at IS NULL AND
        revoked_by_id IS NULL AND
        token_digest IS NOT NULL
      ) OR (
        accepted_at IS NOT NULL AND
        accepted_by_id IS NOT NULL AND
        revoked_at IS NULL AND
        revoked_by_id IS NULL AND
        token_digest IS NULL
      ) OR (
        accepted_at IS NULL AND
        accepted_by_id IS NULL AND
        revoked_at IS NOT NULL AND
        revoked_by_id IS NOT NULL AND
        token_digest IS NULL
      )
    SQL

    # An invitation has exactly one pending, accepted, or revoked state.
    add_check_constraint :workspace_invitations,
      terminal_state,
      name: "workspace_invitations_terminal_state"
  end
end
