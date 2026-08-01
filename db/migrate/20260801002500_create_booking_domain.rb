class CreateBookingDomain < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :availability_windows do |t|
      t.references :shared_resource,
        null: false,
        foreign_key: true
      t.integer :weekday, null: false
      t.integer :starts_minute, null: false
      t.integer :ends_minute, null: false

      t.timestamps
    end

    add_index :availability_windows,
      %i[shared_resource_id weekday],
      name: "index_availability_windows_on_resource_and_weekday"

    add_check_constraint :availability_windows,
      "weekday BETWEEN 0 AND 6",
      name: "availability_windows_weekday_range"

    add_check_constraint :availability_windows,
      "starts_minute BETWEEN 0 AND 1439",
      name: "availability_windows_start_range"

    add_check_constraint :availability_windows,
      "ends_minute BETWEEN 1 AND 1440",
      name: "availability_windows_end_range"

    add_check_constraint :availability_windows,
      "starts_minute < ends_minute",
      name: "availability_windows_positive_duration"

    # Half-open ranges let adjacent windows touch without overlapping.
    add_exclusion_constraint :availability_windows,
      <<~SQL.squish,
        shared_resource_id WITH =,
        weekday WITH =,
        int4range(starts_minute, ends_minute, '[)') WITH &&
      SQL
      using: :gist,
      name: "availability_windows_no_overlap"

    create_table :reservations do |t|
      t.references :shared_resource,
        null: false,
        foreign_key: true
      t.references :user,
        null: false,
        foreign_key: true
      t.string :purpose, null: false
      t.text :notes
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status,
        null: false,
        default: "confirmed"
      t.datetime :cancelled_at
      t.references :cancelled_by,
        foreign_key: {
          to_table: :users
        }

      t.timestamps
    end

    add_index :reservations,
      %i[shared_resource_id starts_at],
      name: "index_reservations_on_resource_and_start"

    add_index :reservations,
      %i[user_id starts_at],
      name: "index_reservations_on_user_and_start"

    add_index :reservations,
      %i[status starts_at]

    add_check_constraint :reservations,
      "ends_at > starts_at",
      name: "reservations_positive_duration"

    add_check_constraint :reservations,
      "ends_at <= starts_at + INTERVAL '12 hours'",
      name: "reservations_maximum_duration"

    add_check_constraint :reservations,
      "status IN ('confirmed', 'cancelled')",
      name: "reservations_status_value"

    add_check_constraint :reservations,
      "char_length(btrim(purpose)) BETWEEN 1 AND 150",
      name: "reservations_purpose_length"

    add_check_constraint :reservations,
      "notes IS NULL OR char_length(notes) <= 1000",
      name: "reservations_notes_length"

    add_check_constraint :reservations,
      <<~SQL.squish,
        (
          status = 'confirmed' AND
          cancelled_at IS NULL AND
          cancelled_by_id IS NULL
        ) OR (
          status = 'cancelled' AND
          cancelled_at IS NOT NULL AND
          cancelled_by_id IS NOT NULL
        )
      SQL
      name: "reservations_cancellation_state"

    # The database constraint remains authoritative during concurrent writes.
    add_exclusion_constraint :reservations,
      <<~SQL.squish,
        shared_resource_id WITH =,
        tsrange(starts_at, ends_at, '[)') WITH &&
      SQL
      using: :gist,
      where: "status = 'confirmed'",
      name: "reservations_no_confirmed_overlap"
  end

  def down
    drop_table :reservations
    drop_table :availability_windows
  end
end
