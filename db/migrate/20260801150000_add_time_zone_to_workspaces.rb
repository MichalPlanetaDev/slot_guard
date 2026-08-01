class AddTimeZoneToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces,
      :time_zone,
      :string,
      null: false,
      default: "Etc/UTC"

    add_check_constraint :workspaces,
      "char_length(time_zone) BETWEEN 1 AND 100",
      name: "workspaces_time_zone_length"
  end
end
