class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_check_constraint :workspaces,
      "char_length(btrim(name)) BETWEEN 1 AND 100",
      name: "workspaces_name_length"
  end
end
