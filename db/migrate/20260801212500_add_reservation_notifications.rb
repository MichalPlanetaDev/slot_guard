class AddReservationNotifications < ActiveRecord::Migration[8.1]
  REMINDER_MINUTES = [ 60, 240, 1_440, 2_880 ].freeze

  def change
    add_column :reservations,
      :reminder_minutes,
      :integer

    add_column :reservation_series,
      :reminder_minutes,
      :integer

    reminder_values =
      REMINDER_MINUTES.join(", ")

    add_check_constraint :reservations,
      "reminder_minutes IS NULL OR reminder_minutes IN (#{reminder_values})",
      name: "reservations_reminder_minutes"

    add_check_constraint :reservation_series,
      "reminder_minutes IS NULL OR reminder_minutes IN (#{reminder_values})",
      name: "reservation_series_reminder_minutes"

    create_table :reservation_reminders do |t|
      t.references :reservation,
        null: false,
        foreign_key: true,
        index: {
          unique: true
        }
      t.datetime :scheduled_for, null: false
      t.datetime :delivered_at
      t.datetime :skipped_at

      t.timestamps
    end

    add_index :reservation_reminders,
      :scheduled_for,
      where: "delivered_at IS NULL AND skipped_at IS NULL",
      name: "index_pending_reservation_reminders_on_schedule"

    # A reminder can be pending, delivered, or skipped, but never both terminal states.
    add_check_constraint :reservation_reminders,
      "delivered_at IS NULL OR skipped_at IS NULL",
      name: "reservation_reminders_single_terminal_state"
  end
end
