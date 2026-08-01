# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_01_002500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "availability_windows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "ends_minute", null: false
    t.bigint "shared_resource_id", null: false
    t.integer "starts_minute", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["shared_resource_id", "weekday"], name: "index_availability_windows_on_resource_and_weekday"
    t.index ["shared_resource_id"], name: "index_availability_windows_on_shared_resource_id"
    t.check_constraint "ends_minute >= 1 AND ends_minute <= 1440", name: "availability_windows_end_range"
    t.check_constraint "starts_minute < ends_minute", name: "availability_windows_positive_duration"
    t.check_constraint "starts_minute >= 0 AND starts_minute <= 1439", name: "availability_windows_start_range"
    t.check_constraint "weekday >= 0 AND weekday <= 6", name: "availability_windows_weekday_range"
    t.exclusion_constraint "shared_resource_id WITH =, weekday WITH =, int4range(starts_minute, ends_minute, '[)'::text) WITH &&", using: :gist, name: "availability_windows_no_overlap"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_memberships_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
    t.check_constraint "role = ANY (ARRAY[0, 1, 2])", name: "memberships_role_value"
  end

  create_table "reservations", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.text "notes"
    t.string "purpose", null: false
    t.bigint "shared_resource_id", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["cancelled_by_id"], name: "index_reservations_on_cancelled_by_id"
    t.index ["shared_resource_id", "starts_at"], name: "index_reservations_on_resource_and_start"
    t.index ["shared_resource_id"], name: "index_reservations_on_shared_resource_id"
    t.index ["status", "starts_at"], name: "index_reservations_on_status_and_starts_at"
    t.index ["user_id", "starts_at"], name: "index_reservations_on_user_and_start"
    t.index ["user_id"], name: "index_reservations_on_user_id"
    t.check_constraint "char_length(btrim(purpose::text)) >= 1 AND char_length(btrim(purpose::text)) <= 150", name: "reservations_purpose_length"
    t.check_constraint "ends_at <= (starts_at + 'PT12H'::interval)", name: "reservations_maximum_duration"
    t.check_constraint "ends_at > starts_at", name: "reservations_positive_duration"
    t.check_constraint "notes IS NULL OR char_length(notes) <= 1000", name: "reservations_notes_length"
    t.check_constraint "status::text = 'confirmed'::text AND cancelled_at IS NULL AND cancelled_by_id IS NULL OR status::text = 'cancelled'::text AND cancelled_at IS NOT NULL AND cancelled_by_id IS NOT NULL", name: "reservations_cancellation_state"
    t.check_constraint "status::text = ANY (ARRAY['confirmed'::character varying, 'cancelled'::character varying]::text[])", name: "reservations_status_value"
    t.exclusion_constraint "shared_resource_id WITH =, tsrange(starts_at, ends_at, '[)'::text) WITH &&", where: "(status)::text = 'confirmed'::text", using: :gist, name: "reservations_no_confirmed_overlap"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shared_resources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "capacity"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "location"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index "workspace_id, lower((name)::text)", name: "index_shared_resources_on_workspace_and_lower_name", unique: true
    t.index ["workspace_id", "active"], name: "index_shared_resources_on_workspace_id_and_active"
    t.index ["workspace_id"], name: "index_shared_resources_on_workspace_id"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "shared_resources_positive_capacity"
    t.check_constraint "category::text = ANY (ARRAY['room'::character varying::text, 'equipment'::character varying::text])", name: "shared_resources_category_value"
    t.check_constraint "char_length(btrim(name::text)) >= 1 AND char_length(btrim(name::text)) <= 100", name: "shared_resources_name_length"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "char_length(btrim(name::text)) >= 1 AND char_length(btrim(name::text)) <= 100", name: "workspaces_name_length"
  end

  add_foreign_key "availability_windows", "shared_resources"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "reservations", "shared_resources"
  add_foreign_key "reservations", "users"
  add_foreign_key "reservations", "users", column: "cancelled_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "shared_resources", "workspaces"
end
