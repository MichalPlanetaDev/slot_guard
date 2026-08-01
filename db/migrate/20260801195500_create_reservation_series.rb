class CreateReservationSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :reservation_series do |t|
      t.references :shared_resource,
        null: false,
        foreign_key: true
      t.references :user,
        null: false,
        foreign_key: true
      t.string :purpose, null: false
      t.text :notes
      t.datetime :first_starts_at, null: false
      t.datetime :first_ends_at, null: false
      t.string :time_zone, null: false
      t.integer :interval_weeks, null: false, default: 1
      t.integer :occurrence_count, null: false

      t.timestamps
    end

    add_check_constraint :reservation_series,
      "char_length(btrim(purpose)) BETWEEN 1 AND 150",
      name: "reservation_series_purpose_length"

    add_check_constraint :reservation_series,
      "notes IS NULL OR char_length(notes) <= 1000",
      name: "reservation_series_notes_length"

    add_check_constraint :reservation_series,
      "char_length(time_zone) BETWEEN 1 AND 100",
      name: "reservation_series_time_zone_length"

    add_check_constraint :reservation_series,
      "interval_weeks BETWEEN 1 AND 12",
      name: "reservation_series_interval_weeks"

    add_check_constraint :reservation_series,
      "occurrence_count BETWEEN 2 AND 26",
      name: "reservation_series_occurrence_count"

    add_check_constraint :reservation_series,
      "first_ends_at > first_starts_at",
      name: "reservation_series_positive_duration"

    add_check_constraint :reservation_series,
      "first_ends_at <= first_starts_at + INTERVAL '12 hours'",
      name: "reservation_series_maximum_duration"

    add_reference :reservations,
      :reservation_series,
      foreign_key: {
        to_table: :reservation_series
      }

    add_column :reservations,
      :occurrence_number,
      :integer

    add_index :reservations,
      %i[reservation_series_id occurrence_number],
      unique: true,
      where: "reservation_series_id IS NOT NULL",
      name: "index_reservations_on_series_and_occurrence"

    # Generated occurrences carry both values; one-off reservations carry neither.
    series_occurrence_pair = <<~SQL.squish
      (
        reservation_series_id IS NULL AND
        occurrence_number IS NULL
      ) OR (
        reservation_series_id IS NOT NULL AND
        occurrence_number IS NOT NULL
      )
    SQL

    add_check_constraint :reservations,
      series_occurrence_pair,
      name: "reservations_series_occurrence_pair"

    add_check_constraint :reservations,
      "occurrence_number IS NULL OR occurrence_number BETWEEN 1 AND 26",
      name: "reservations_occurrence_number"
  end
end
