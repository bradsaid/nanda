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

ActiveRecord::Schema[8.0].define(version: 2025_09_12_220113) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "appearance_items", force: :cascade do |t|
    t.bigint "appearance_id", null: false
    t.bigint "item_id", null: false
    t.string "source", null: false
    t.integer "quantity", default: 1, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appearance_id", "item_id", "source"], name: "index_appearance_items_on_appearance_id_and_item_id_and_source", unique: true
    t.index ["appearance_id"], name: "index_appearance_items_on_appearance_id"
    t.index ["item_id"], name: "index_appearance_items_on_item_id"
  end

  create_table "appearances", force: :cascade do |t|
    t.bigint "survivor_id", null: false
    t.bigint "episode_id", null: false
    t.decimal "starting_psr", precision: 5, scale: 2
    t.decimal "ending_psr", precision: 5, scale: 2
    t.integer "days_lasted"
    t.string "result"
    t.string "role"
    t.boolean "partner_replacement"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_appearances_on_episode_id"
    t.index ["survivor_id", "episode_id"], name: "index_appearances_on_survivor_id_and_episode_id", unique: true
    t.index ["survivor_id"], name: "index_appearances_on_survivor_id"
    t.check_constraint "days_lasted IS NULL OR days_lasted >= 0", name: "appearances_days_lasted_nonneg"
    t.check_constraint "ending_psr >= 0::numeric AND ending_psr <= 10::numeric", name: "appearances_ending_psr_0_10"
    t.check_constraint "starting_psr >= 0::numeric AND starting_psr <= 10::numeric", name: "appearances_starting_psr_0_10"
  end

  create_table "episodes", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.integer "number_in_season", null: false
    t.string "title", null: false
    t.date "air_date"
    t.integer "scheduled_days"
    t.string "participant_arrangement"
    t.string "type_modifiers"
    t.bigint "location_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_episodes_on_location_id"
    t.index ["season_id", "number_in_season"], name: "index_episodes_on_season_id_and_number_in_season", unique: true
    t.index ["season_id"], name: "index_episodes_on_season_id"
  end

  create_table "items", force: :cascade do |t|
    t.citext "name", null: false
    t.string "item_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_items_on_name", unique: true
  end

  create_table "locations", force: :cascade do |t|
    t.string "country"
    t.string "region"
    t.string "site"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.index ["country", "region", "site"], name: "index_locations_on_country_and_region_and_site"
    t.index ["country"], name: "index_locations_on_country"
    t.index ["latitude", "longitude"], name: "index_locations_on_latitude_and_longitude"
  end

  create_table "seasons", force: :cascade do |t|
    t.bigint "series_id", null: false
    t.integer "number"
    t.integer "year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["series_id", "number"], name: "index_seasons_on_series_id_and_number", unique: true
    t.index ["series_id"], name: "index_seasons_on_series_id"
  end

  create_table "series", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_series_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "survivors", force: :cascade do |t|
    t.citext "full_name", null: false
    t.text "bio"
    t.string "instagram"
    t.string "facebook"
    t.string "youtube"
    t.string "website"
    t.string "onlyfans"
    t.string "merch"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["full_name"], name: "index_survivors_on_full_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "appearance_items", "appearances"
  add_foreign_key "appearance_items", "items"
  add_foreign_key "appearances", "episodes"
  add_foreign_key "appearances", "survivors"
  add_foreign_key "episodes", "locations"
  add_foreign_key "episodes", "seasons"
  add_foreign_key "seasons", "series"
  add_foreign_key "sessions", "users"
end
