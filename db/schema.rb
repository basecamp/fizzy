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

ActiveRecord::Schema[8.2].define(version: 2025_11_02_115338) do
  create_table "accesses", force: :cascade do |t|
    t.datetime "accessed_at"
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "involvement", default: "access_only", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["accessed_at"], name: "index_accesses_on_accessed_at", order: :desc
    t.index ["collection_id", "user_id"], name: "index_accesses_on_collection_id_and_user_id", unique: true
    t.index ["collection_id"], name: "index_accesses_on_collection_id"
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "account_join_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "usage_limit", default: 10, null: false
    t.index ["code"], name: "index_account_join_codes_on_code", unique: true
  end

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "external_account_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id"], name: "index_accounts_on_external_account_id", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
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

  create_table "card_activity_spikes", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_activity_spikes_on_card_id"
  end

  create_table "card_engagements", force: :cascade do |t|
    t.integer "card_id"
    t.datetime "created_at", null: false
    t.string "status", default: "doing", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_engagements_on_card_id"
    t.index ["status"], name: "index_card_engagements_on_status"
  end

  create_table "card_goldnesses", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_goldnesses_on_card_id", unique: true
  end

  create_table "card_not_nows", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["card_id"], name: "index_card_not_nows_on_card_id", unique: true
    t.index ["user_id"], name: "index_card_not_nows_on_user_id"
  end

  create_table "cards", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.integer "column_id"
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.date "due_on"
    t.datetime "last_active_at", null: false
    t.text "status", default: "drafted", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_cards_on_collection_id"
    t.index ["column_id"], name: "index_cards_on_column_id"
    t.index ["last_active_at", "status"], name: "index_cards_on_last_active_at_and_status"
  end

  create_table "closers_filters", id: false, force: :cascade do |t|
    t.integer "closer_id", null: false
    t.integer "filter_id", null: false
    t.index ["closer_id"], name: "index_closers_filters_on_closer_id"
    t.index ["filter_id"], name: "index_closers_filters_on_filter_id"
  end

  create_table "closures", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["card_id", "created_at"], name: "index_closures_on_card_id_and_created_at"
    t.index ["card_id"], name: "index_closures_on_card_id", unique: true
    t.index ["user_id"], name: "index_closures_on_user_id"
  end

  create_table "collection_publications", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_collection_publications_on_collection_id"
    t.index ["key"], name: "index_collection_publications_on_key", unique: true
  end

  create_table "collections", force: :cascade do |t|
    t.boolean "all_access", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_collections_on_creator_id"
  end

  create_table "collections_filters", id: false, force: :cascade do |t|
    t.integer "collection_id", null: false
    t.integer "filter_id", null: false
    t.index ["collection_id"], name: "index_collections_filters_on_collection_id"
    t.index ["filter_id"], name: "index_collections_filters_on_filter_id"
  end

  create_table "columns", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "position"], name: "index_columns_on_collection_id_and_position"
    t.index ["collection_id"], name: "index_columns_on_collection_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_comments_on_card_id"
  end

  create_table "creators_filters", id: false, force: :cascade do |t|
    t.integer "creator_id", null: false
    t.integer "filter_id", null: false
    t.index ["creator_id"], name: "index_creators_filters_on_creator_id"
    t.index ["filter_id"], name: "index_creators_filters_on_filter_id"
  end

  create_table "entropies", force: :cascade do |t|
    t.bigint "auto_postpone_period", default: 2592000, null: false
    t.integer "container_id", null: false
    t.string "container_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["container_type", "container_id", "auto_postpone_period"], name: "idx_on_container_type_container_id_auto_postpone_pe_3d79b50517"
    t.index ["container_type", "container_id"], name: "index_entropy_configurations_on_container", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.integer "eventable_id", null: false
    t.string "eventable_type", null: false
    t.json "particulars", default: {}
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_events_on_summary_id_and_action"
    t.index ["collection_id", "action", "created_at"], name: "index_events_on_collection_id_and_action_and_created_at"
    t.index ["collection_id"], name: "index_events_on_collection_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
  end

  create_table "filters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.json "fields", default: {}, null: false
    t.string "params_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id", "params_digest"], name: "index_filters_on_creator_id_and_params_digest", unique: true
  end

  create_table "filters_tags", id: false, force: :cascade do |t|
    t.integer "filter_id", null: false
    t.integer "tag_id", null: false
    t.index ["filter_id"], name: "index_filters_tags_on_filter_id"
    t.index ["tag_id"], name: "index_filters_tags_on_tag_id"
  end

  create_table "mentions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "mentionee_id", null: false
    t.integer "mentioner_id", null: false
    t.integer "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["mentionee_id"], name: "index_mentions_on_mentionee_id"
    t.index ["mentioner_id"], name: "index_mentions_on_mentioner_id"
    t.index ["source_type", "source_id"], name: "index_mentions_on_source"
  end

  create_table "notification_bundles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ends_at", "status"], name: "index_notification_bundles_on_ends_at_and_status"
    t.index ["user_id", "starts_at", "ends_at"], name: "idx_on_user_id_starts_at_ends_at_7eae5d3ac5"
    t.index ["user_id", "status"], name: "index_notification_bundles_on_user_id_and_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id"
    t.datetime "read_at"
    t.integer "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["creator_id"], name: "index_notifications_on_creator_id"
    t.index ["source_type", "source_id"], name: "index_notifications_on_source"
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

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key"
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "p256dh_key"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["endpoint", "p256dh_key", "auth_key"], name: "idx_on_endpoint_p256dh_key_auth_key_7553014576"
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint"
    t.index ["user_agent"], name: "index_push_subscriptions_on_user_agent"
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
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

  create_table "search_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "terms", limit: 2000, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "terms"], name: "index_search_queries_on_user_id_and_terms"
    t.index ["user_id", "updated_at"], name: "index_search_queries_on_user_id_and_updated_at", unique: true
    t.index ["user_id"], name: "index_search_queries_on_user_id"
  end

  create_table "search_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "steps", force: :cascade do |t|
    t.integer "card_id", null: false
    t.boolean "completed", default: false, null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "completed"], name: "index_steps_on_card_id_and_completed"
    t.index ["card_id"], name: "index_steps_on_card_id"
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
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_tags_on_title", unique: true
  end

  create_table "user_settings", force: :cascade do |t|
    t.integer "bundle_email_frequency", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "timezone_name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "bundle_email_frequency"], name: "index_user_settings_on_user_id_and_bundle_email_frequency"
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address"
    t.integer "membership_id"
    t.string "name", null: false
    t.string "password_digest"
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["membership_id"], name: "index_users_on_membership_id"
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

  create_table "webhook_delinquency_trackers", force: :cascade do |t|
    t.integer "consecutive_failures_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "first_failure_at"
    t.datetime "updated_at", null: false
    t.integer "webhook_id", null: false
    t.index ["webhook_id"], name: "index_webhook_delinquency_trackers_on_webhook_id"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.text "request"
    t.text "response"
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.integer "webhook_id", null: false
    t.index ["event_id"], name: "index_webhook_deliveries_on_event_id"
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.string "signing_secret", null: false
    t.text "subscribed_actions"
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.index ["collection_id"], name: "index_webhooks_on_collection_id"
    t.index ["subscribed_actions"], name: "index_webhooks_on_subscribed_actions"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "card_activity_spikes", "cards"
  add_foreign_key "card_goldnesses", "cards"
  add_foreign_key "card_not_nows", "cards"
  add_foreign_key "card_not_nows", "users"
  add_foreign_key "cards", "columns"
  add_foreign_key "closures", "cards"
  add_foreign_key "closures", "users"
  add_foreign_key "collection_publications", "collections"
  add_foreign_key "columns", "collections"
  add_foreign_key "comments", "cards"
  add_foreign_key "events", "collections"
  add_foreign_key "mentions", "users", column: "mentionee_id"
  add_foreign_key "mentions", "users", column: "mentioner_id"
  add_foreign_key "notification_bundles", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "creator_id"
  add_foreign_key "pins", "cards"
  add_foreign_key "pins", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "search_queries", "users"
  add_foreign_key "steps", "cards"
  add_foreign_key "taggings", "cards"
  add_foreign_key "taggings", "tags"
  add_foreign_key "user_settings", "users"
  add_foreign_key "watches", "cards"
  add_foreign_key "watches", "users"
  add_foreign_key "webhook_delinquency_trackers", "webhooks"
  add_foreign_key "webhook_deliveries", "events"
  add_foreign_key "webhook_deliveries", "webhooks"
  add_foreign_key "webhooks", "collections"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "cards_search_index", "fts5", ["title", "description", "tokenize='porter'"]
  create_virtual_table "comments_search_index", "fts5", ["body", "tokenize='porter'"]
end
