class CreateBlackoutPeriods < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :blackout_periods do |t|
      t.references :workspace,
        null: false,
        foreign_key: true
      t.references :shared_resource,
        foreign_key: true
      t.references :created_by,
        null: false,
        foreign_key: {
          to_table: :users
        }
      t.string :reason,
        null: false,
        limit: 150
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day,
        null: false,
        default: false
      t.string :time_zone,
        null: false,
        limit: 100

      t.timestamps
    end

    add_index :blackout_periods,
      %i[workspace_id starts_at],
      name: "index_blackout_periods_on_workspace_and_start"

    add_index :blackout_periods,
      %i[shared_resource_id starts_at],
      name: "index_blackout_periods_on_resource_and_start"

    add_check_constraint :blackout_periods,
      "ends_at > starts_at",
      name: "blackout_periods_positive_duration"

    add_check_constraint :blackout_periods,
      "char_length(btrim(reason)) BETWEEN 1 AND 150",
      name: "blackout_periods_reason_length"

    add_check_constraint :blackout_periods,
      "char_length(btrim(time_zone)) BETWEEN 1 AND 100",
      name: "blackout_periods_time_zone_length"

    create_table :schedule_blocks do |t|
      t.references :workspace,
        null: false,
        foreign_key: true
      t.references :shared_resource,
        foreign_key: true
      t.bigint :reservation_id
      t.bigint :blackout_period_id
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :active,
        null: false,
        default: true

      t.timestamps
    end

    add_index :schedule_blocks,
      :reservation_id,
      unique: true,
      where: "reservation_id IS NOT NULL"

    add_index :schedule_blocks,
      :blackout_period_id,
      unique: true,
      where: "blackout_period_id IS NOT NULL"

    add_index :schedule_blocks,
      %i[workspace_id starts_at],
      where: "active",
      name: "index_active_schedule_blocks_on_workspace_and_start"

    add_foreign_key :schedule_blocks,
      :reservations

    add_foreign_key :schedule_blocks,
      :blackout_periods

    add_check_constraint :schedule_blocks,
      "ends_at > starts_at",
      name: "schedule_blocks_positive_duration"

    add_check_constraint :schedule_blocks,
      "num_nonnulls(reservation_id, blackout_period_id) = 1",
      name: "schedule_blocks_one_source"

    add_check_constraint :schedule_blocks,
      "reservation_id IS NULL OR shared_resource_id IS NOT NULL",
      name: "schedule_blocks_reservations_require_resource"

    execute <<~SQL
      INSERT INTO schedule_blocks (
        workspace_id,
        shared_resource_id,
        reservation_id,
        starts_at,
        ends_at,
        active,
        created_at,
        updated_at
      )
      SELECT
        shared_resources.workspace_id,
        reservations.shared_resource_id,
        reservations.id,
        reservations.starts_at,
        reservations.ends_at,
        reservations.status = 'confirmed',
        reservations.created_at,
        reservations.updated_at
      FROM reservations
      INNER JOIN shared_resources
        ON shared_resources.id = reservations.shared_resource_id
    SQL

    # NULL bounds produce the unbounded range used by workspace closures.
    # A non-NULL identifier produces a singleton resource range.
    add_exclusion_constraint :schedule_blocks,
      <<~SQL.squish,
        workspace_id WITH =,
        int8range(
          shared_resource_id,
          shared_resource_id,
          '[]'
        ) WITH &&,
        tsrange(starts_at, ends_at, '[)') WITH &&
      SQL
      using: :gist,
      where: "active",
      name: "schedule_blocks_no_overlap"
  end

  def down
    drop_table :schedule_blocks
    drop_table :blackout_periods
  end
end
