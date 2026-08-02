class AddBookingPolicies < ActiveRecord::Migration[8.1]
  POLICY_COLUMNS = {
    minimum_booking_notice_minutes: {
      default: 0,
      minimum: 0,
      maximum: 10_080
    },
    maximum_advance_booking_days: {
      default: 365,
      minimum: 1,
      maximum: 3_650
    },
    maximum_reservation_duration_minutes: {
      default: 720,
      minimum: 15,
      maximum: 1_440
    },
    cancellation_cutoff_minutes: {
      default: 0,
      minimum: 0,
      maximum: 10_080
    }
  }.freeze

  def change
    POLICY_COLUMNS.each do |column, settings|
      add_column :workspaces,
        column,
        :integer,
        null: false,
        default: settings.fetch(:default)

      add_column :shared_resources,
        column,
        :integer

      add_check_constraint :workspaces,
        "#{column} BETWEEN " \
          "#{settings.fetch(:minimum)} AND " \
          "#{settings.fetch(:maximum)}",
        name: "workspaces_#{column}_range"

      add_check_constraint :shared_resources,
        "#{column} IS NULL OR " \
          "#{column} BETWEEN " \
          "#{settings.fetch(:minimum)} AND " \
          "#{settings.fetch(:maximum)}",
        name: "shared_resources_#{column}_range"
    end
  end
end
