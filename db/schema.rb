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

ActiveRecord::Schema[8.1].define(version: 2025_04_09_043626) do
  create_table "accesses", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "involvement", default: "watching", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["collection_id", "user_id"], name: "index_accesses_on_collection_id_and_user_id", unique: true
    t.index ["collection_id"], name: "index_accesses_on_collection_id"
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "join_code"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_accounts_on_join_code", unique: true
    t.index ["name"], name: "index_accounts_on_name", unique: true
  end

  create_table "action_text_markdowns", force: :cascade do |t|
    t.text "content", default: "", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_action_text_markdowns_on_record"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.string "slug"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
    t.index ["slug"], name: "index_active_storage_attachments_on_slug", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assignees_filters", id: false, force: :cascade do |t|
    t.integer "assignee_id", null: false
    t.integer "filter_id", null: false
    t.index ["assignee_id"], name: "index_assignees_filters_on_assignee_id"
    t.index ["filter_id"], name: "index_assignees_filters_on_filter_id"
  end

  create_table "assigners_filters", id: false, force: :cascade do |t|
    t.integer "assigner_id", null: false
    t.integer "filter_id", null: false
    t.index ["assigner_id"], name: "index_assigners_filters_on_assigner_id"
    t.index ["filter_id"], name: "index_assigners_filters_on_filter_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.integer "assignee_id", null: false
    t.integer "assigner_id", null: false
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "card_id"], name: "index_assignments_on_assignee_id_and_card_id", unique: true
    t.index ["card_id"], name: "index_assignments_on_card_id"
  end

  create_table "card_engagements", force: :cascade do |t|
    t.integer "card_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_engagements_on_card_id"
  end

  create_table "cards", force: :cascade do |t|
    t.float "activity_score", default: 0.0, null: false
    t.datetime "activity_score_at"
    t.float "activity_score_order", default: 0.0, null: false
    t.integer "boosts_count", default: 0, null: false
    t.integer "collection_id", null: false
    t.string "color"
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.date "due_on"
    t.datetime "last_active_at", null: false
    t.integer "stage_id"
    t.text "status", default: "creating", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["activity_score_order"], name: "index_cards_on_activity_score_order"
    t.index ["collection_id"], name: "index_cards_on_collection_id"
    t.index ["last_active_at", "status"], name: "index_cards_on_last_active_at_and_status"
    t.index ["stage_id"], name: "index_cards_on_stage_id"
  end

  create_table "closure_reasons", force: :cascade do |t|
    t.integer "account_id"
    t.datetime "created_at", null: false
    t.string "label"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_closure_reasons_on_account_id"
  end

  create_table "closures", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["card_id", "created_at"], name: "index_closures_on_card_id_and_created_at"
    t.index ["card_id"], name: "index_closures_on_card_id", unique: true
    t.index ["user_id"], name: "index_closures_on_user_id"
  end

  create_table "collections", force: :cascade do |t|
    t.integer "account_id", null: false
    t.boolean "all_access", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_id"
    t.index ["account_id"], name: "index_collections_on_account_id"
    t.index ["creator_id"], name: "index_collections_on_creator_id"
    t.index ["workflow_id"], name: "index_collections_on_workflow_id"
  end

  create_table "collections_filters", id: false, force: :cascade do |t|
    t.integer "collection_id", null: false
    t.integer "filter_id", null: false
    t.index ["collection_id"], name: "index_collections_filters_on_collection_id"
    t.index ["filter_id"], name: "index_collections_filters_on_filter_id"
  end

  create_table "comments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "creators_filters", id: false, force: :cascade do |t|
    t.integer "creator_id", null: false
    t.integer "filter_id", null: false
    t.index ["creator_id"], name: "index_creators_filters_on_creator_id"
    t.index ["filter_id"], name: "index_creators_filters_on_filter_id"
  end

  create_table "event_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.date "due_date"
    t.json "particulars", default: {}
    t.integer "summary_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_events_on_card_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["summary_id", "action"], name: "index_events_on_summary_id_and_action"
  end

  create_table "filters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.json "fields", default: {}, null: false
    t.string "params_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id", "params_digest"], name: "index_filters_on_creator_id_and_params_digest", unique: true
  end

  create_table "filters_stages", id: false, force: :cascade do |t|
    t.integer "filter_id", null: false
    t.integer "stage_id", null: false
    t.index ["filter_id"], name: "index_filters_stages_on_filter_id"
    t.index ["stage_id"], name: "index_filters_stages_on_stage_id"
  end

  create_table "filters_tags", id: false, force: :cascade do |t|
    t.integer "filter_id", null: false
    t.integer "tag_id", null: false
    t.index ["filter_id"], name: "index_filters_tags_on_filter_id"
    t.index ["tag_id"], name: "index_filters_tags_on_tag_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "messageable_id", null: false
    t.string "messageable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_messages_on_card_id"
    t.index ["messageable_type", "messageable_id"], name: "index_messages_on_messageable", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.datetime "read_at"
    t.integer "resource_id", null: false
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["card_id"], name: "index_notifications_on_card_id"
    t.index ["event_id"], name: "index_notifications_on_event_id"
    t.index ["resource_type", "resource_id"], name: "index_notifications_on_resource"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_id_and_read_at_and_created_at", order: { read_at: :desc, created_at: :desc }
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "pins", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["card_id", "user_id"], name: "index_pins_on_card_id_and_user_id", unique: true
    t.index ["card_id"], name: "index_pins_on_card_id"
    t.index ["user_id"], name: "index_pins_on_user_id"
  end

  create_table "reactions", force: :cascade do |t|
    t.integer "comment_id", null: false
    t.string "content", limit: 16, null: false
    t.datetime "created_at", null: false
    t.integer "reacter_id", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_reactions_on_comment_id"
    t.index ["reacter_id"], name: "index_reactions_on_reacter_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "tag_id"], name: "index_taggings_on_card_id_and_tag_id", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["account_id", "title"], name: "index_tags_on_account_id_and_title", unique: true
    t.index ["account_id"], name: "index_tags_on_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "name", null: false
    t.string "password_digest"
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "watches", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.boolean "watching", default: true, null: false
    t.index ["card_id"], name: "index_watches_on_card_id"
    t.index ["user_id"], name: "index_watches_on_user_id"
  end

  create_table "workflow_stages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_id", null: false
    t.index ["workflow_id"], name: "index_workflow_stages_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_workflows_on_account_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cards", "workflow_stages", column: "stage_id"
  add_foreign_key "closures", "cards"
  add_foreign_key "closures", "users"
  add_foreign_key "collections", "workflows"
  add_foreign_key "events", "cards"
  add_foreign_key "events", "event_summaries", column: "summary_id"
  add_foreign_key "messages", "cards"
  add_foreign_key "notifications", "cards"
  add_foreign_key "notifications", "events"
  add_foreign_key "notifications", "users"
  add_foreign_key "pins", "cards"
  add_foreign_key "pins", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "taggings", "cards"
  add_foreign_key "taggings", "tags"
  add_foreign_key "users", "accounts"
  add_foreign_key "watches", "cards"
  add_foreign_key "watches", "users"
  add_foreign_key "workflow_stages", "workflows"
  add_foreign_key "workflows", "accounts"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "cards_search_index", "fts5", ["title"]
  create_virtual_table "comments_search_index", "fts5", ["body"]
end
