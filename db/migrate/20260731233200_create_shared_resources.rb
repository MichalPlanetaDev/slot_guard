class CreateSharedResources < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_resources do |t|
      t.references :workspace,
        null: false,
        foreign_key: true
      t.string :name, null: false
      t.string :category, null: false
      t.string :location
      t.integer :capacity
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :shared_resources,
      "workspace_id, lower(name)",
      unique: true,
      name: "index_shared_resources_on_workspace_and_lower_name"

    add_index :shared_resources,
      %i[workspace_id active]

    add_check_constraint :shared_resources,
      "char_length(btrim(name)) BETWEEN 1 AND 100",
      name: "shared_resources_name_length"

    add_check_constraint :shared_resources,
      "category IN ('room', 'equipment')",
      name: "shared_resources_category_value"

    add_check_constraint :shared_resources,
      "capacity IS NULL OR capacity > 0",
      name: "shared_resources_positive_capacity"
  end
end
