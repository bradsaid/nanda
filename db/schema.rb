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

ActiveRecord::Schema[8.0].define(version: 2026_07_19_120014) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appearance_items", force: :cascade do |t|
    t.bigint "appearance_id", null: false
    t.bigint "item_id", null: false
    t.string "source", null: false
    t.integer "quantity", default: 1, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subtype"
    t.index "appearance_id, item_id, COALESCE(subtype, ''::character varying), source", name: "index_appearance_items_unique_with_subtype", unique: true
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
    t.bigint "location_id"
    t.decimal "weight_loss"
    t.index ["episode_id"], name: "index_appearances_on_episode_id"
    t.index ["location_id"], name: "index_appearances_on_location_id"
    t.index ["survivor_id", "episode_id"], name: "index_appearances_on_survivor_id_and_episode_id", unique: true
    t.index ["survivor_id"], name: "index_appearances_on_survivor_id"
    t.check_constraint "days_lasted IS NULL OR days_lasted >= 0", name: "appearances_days_lasted_nonneg"
    t.check_constraint "ending_psr >= 0::numeric AND ending_psr <= 10::numeric", name: "appearances_ending_psr_0_10"
    t.check_constraint "starting_psr >= 0::numeric AND starting_psr <= 10::numeric", name: "appearances_starting_psr_0_10"
  end

  create_table "bushcraft_items", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.integer "builder_ids", default: [], null: false, array: true
    t.string "item_type"
    t.string "materials"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["builder_ids"], name: "index_bushcraft_items_on_builder_ids", using: :gin
    t.index ["episode_id"], name: "index_bushcraft_items_on_episode_id"
  end

  create_table "episode_shelters", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.string "shelter_type"
    t.string "materials"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "builder_ids", default: [], array: true
    t.index ["episode_id"], name: "index_episode_shelters_on_episode_id"
  end

  create_table "episode_traps", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.string "trap_type", null: false
    t.string "result"
    t.integer "builder_ids", default: [], array: true
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_episode_traps_on_episode_id"
  end

  create_table "episodes", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.integer "number_in_season", null: false
    t.string "title", null: false
    t.date "air_date"
    t.integer "scheduled_days"
    t.string "participant_arrangement"
    t.string "type_modifiers"
    t.bigint "location_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "synopsis"
    t.boolean "no_traps", default: false, null: false
    t.index ["location_id"], name: "index_episodes_on_location_id"
    t.index ["season_id", "number_in_season"], name: "index_episodes_on_season_id_and_number_in_season", unique: true
    t.index ["season_id"], name: "index_episodes_on_season_id"
  end

  create_table "food_sources", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.string "category", null: false
    t.string "name", null: false
    t.string "method"
    t.string "tools_used"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "episode_trap_id"
    t.integer "survivor_ids", default: [], array: true
    t.integer "quantity"
    t.index ["episode_id"], name: "index_food_sources_on_episode_id"
    t.index ["episode_trap_id"], name: "index_food_sources_on_episode_trap_id"
    t.index ["name", "episode_id"], name: "index_food_sources_on_name_and_episode_id"
  end

  create_table "forum_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.boolean "locked", default: false, null: false
    t.integer "topics_count", default: 0, null: false
    t.datetime "last_topic_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_forum_categories_on_position"
    t.index ["slug"], name: "index_forum_categories_on_slug", unique: true
  end

  create_table "forum_posts", force: :cascade do |t|
    t.bigint "forum_topic_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.text "body_html"
    t.datetime "edited_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_forum_posts_on_deleted_at"
    t.index ["forum_topic_id", "created_at"], name: "index_forum_posts_on_forum_topic_id_and_created_at"
    t.index ["forum_topic_id"], name: "index_forum_posts_on_forum_topic_id"
    t.index ["user_id"], name: "index_forum_posts_on_user_id"
  end

  create_table "forum_reports", force: :cascade do |t|
    t.bigint "reporter_id", null: false
    t.string "reportable_type", null: false
    t.bigint "reportable_id", null: false
    t.integer "reason", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.bigint "handled_by_id"
    t.datetime "handled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handled_by_id"], name: "index_forum_reports_on_handled_by_id"
    t.index ["reportable_type", "reportable_id"], name: "index_forum_reports_on_reportable"
    t.index ["reportable_type", "reportable_id"], name: "index_forum_reports_on_reportable_type_and_reportable_id"
    t.index ["reporter_id"], name: "index_forum_reports_on_reporter_id"
    t.index ["status"], name: "index_forum_reports_on_status"
  end

  create_table "forum_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "forum_topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["forum_topic_id"], name: "index_forum_subscriptions_on_forum_topic_id"
    t.index ["user_id", "forum_topic_id"], name: "index_forum_subscriptions_on_user_id_and_forum_topic_id", unique: true
    t.index ["user_id"], name: "index_forum_subscriptions_on_user_id"
  end

  create_table "forum_topics", force: :cascade do |t|
    t.bigint "forum_category_id", null: false
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.boolean "pinned", default: false, null: false
    t.boolean "locked", default: false, null: false
    t.integer "posts_count", default: 0, null: false
    t.integer "views_count", default: 0, null: false
    t.datetime "last_post_at"
    t.bigint "last_post_user_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_forum_topics_on_deleted_at"
    t.index ["forum_category_id", "slug"], name: "index_forum_topics_on_forum_category_id_and_slug", unique: true
    t.index ["forum_category_id"], name: "index_forum_topics_on_forum_category_id"
    t.index ["last_post_at"], name: "index_forum_topics_on_last_post_at"
    t.index ["last_post_user_id"], name: "index_forum_topics_on_last_post_user_id"
    t.index ["pinned"], name: "index_forum_topics_on_pinned"
    t.index ["user_id"], name: "index_forum_topics_on_user_id"
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

  create_table "medical_calls", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.bigint "survivor_id"
    t.string "reason"
    t.boolean "led_to_tapout", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_medical_calls_on_episode_id"
    t.index ["survivor_id"], name: "index_medical_calls_on_survivor_id"
  end

  create_table "page_views", force: :cascade do |t|
    t.string "path"
    t.string "controller_name"
    t.string "action_name"
    t.string "method"
    t.string "ip_address"
    t.string "user_agent"
    t.string "referrer"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "country"
    t.string "city"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "session_id"
    t.integer "duration_seconds"
    t.string "referrer_domain"
    t.string "visitor_id"
    t.index ["controller_name"], name: "index_page_views_on_controller_name"
    t.index ["created_at"], name: "index_page_views_on_created_at"
    t.index ["path"], name: "index_page_views_on_path"
    t.index ["session_id"], name: "index_page_views_on_session_id"
    t.index ["visitor_id"], name: "index_page_views_on_visitor_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.bigint "series_id", null: false
    t.integer "number"
    t.integer "year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "continuous_story", default: false, null: false
    t.text "intro"
    t.index ["continuous_story"], name: "index_seasons_on_continuous_story"
    t.index ["series_id", "number"], name: "index_seasons_on_series_id_and_number", unique: true
    t.index ["series_id"], name: "index_seasons_on_series_id"
  end

  create_table "series", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "continuous_story", default: false, null: false
    t.index ["continuous_story"], name: "index_series_on_continuous_story"
    t.index ["name"], name: "index_series_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "token"
    t.datetime "remembered_until"
    t.index ["token"], name: "index_sessions_on_token", unique: true, where: "(token IS NOT NULL)"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
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
    t.string "avatar_url"
    t.string "slug"
    t.string "cameo"
    t.string "other"
    t.string "bio_source_url"
    t.string "bio_lookup_status", default: "pending", null: false
    t.datetime "bio_checked_at"
    t.index ["bio_lookup_status"], name: "index_survivors_on_bio_lookup_status"
    t.index ["full_name"], name: "index_survivors_on_full_name", unique: true
    t.index ["slug"], name: "index_survivors_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "username"
    t.datetime "email_verified_at"
    t.datetime "banned_at"
    t.text "ban_reason"
    t.integer "posts_count", default: 0, null: false
    t.datetime "last_seen_at"
    t.index ["banned_at"], name: "index_users_on_banned_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true, where: "(username IS NOT NULL)"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appearance_items", "appearances"
  add_foreign_key "appearance_items", "items"
  add_foreign_key "appearances", "episodes"
  add_foreign_key "appearances", "locations"
  add_foreign_key "appearances", "survivors"
  add_foreign_key "bushcraft_items", "episodes"
  add_foreign_key "episode_shelters", "episodes"
  add_foreign_key "episode_traps", "episodes"
  add_foreign_key "episodes", "locations"
  add_foreign_key "episodes", "seasons"
  add_foreign_key "food_sources", "episode_traps"
  add_foreign_key "food_sources", "episodes"
  add_foreign_key "forum_posts", "forum_topics"
  add_foreign_key "forum_posts", "users"
  add_foreign_key "forum_reports", "users", column: "handled_by_id"
  add_foreign_key "forum_reports", "users", column: "reporter_id"
  add_foreign_key "forum_subscriptions", "forum_topics"
  add_foreign_key "forum_subscriptions", "users"
  add_foreign_key "forum_topics", "forum_categories"
  add_foreign_key "forum_topics", "users"
  add_foreign_key "forum_topics", "users", column: "last_post_user_id"
  add_foreign_key "medical_calls", "episodes"
  add_foreign_key "medical_calls", "survivors"
  add_foreign_key "seasons", "series"
  add_foreign_key "sessions", "users"
end
