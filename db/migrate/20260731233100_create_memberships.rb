class CreateMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :memberships do |t|
      t.references :workspace,
        null: false,
        foreign_key: true
      t.references :user,
        null: false,
        foreign_key: true
      t.integer :role,
        null: false,
        default: 0

      t.timestamps
    end

    add_index :memberships,
      %i[workspace_id user_id],
      unique: true

    add_check_constraint :memberships,
      "role IN (0, 1, 2)",
      name: "memberships_role_value"

    backfill_personal_workspaces
  end

  def down
    drop_table :memberships
  end

  private

  def backfill_personal_workspaces
    connection.select_all(
      "SELECT id, name FROM users ORDER BY id"
    ).each do |user|
      workspace_name = "#{user.fetch("name")}'s workspace"
      quoted_name = connection.quote(workspace_name)

      workspace_id = connection.select_value(
        <<~SQL.squish
          INSERT INTO workspaces (name, created_at, updated_at)
          VALUES (#{quoted_name}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          RETURNING id
        SQL
      )

      execute <<~SQL.squish
        INSERT INTO memberships (
          workspace_id,
          user_id,
          role,
          created_at,
          updated_at
        )
        VALUES (
          #{connection.quote(workspace_id)},
          #{connection.quote(user.fetch("id"))},
          2,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end
end
