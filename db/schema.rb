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

ActiveRecord::Schema[8.2].define(version: 2025_12_19_120755) do
  create_table "accesses", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "accessed_at"
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.string "involvement", default: "access_only", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id", "accessed_at"], name: "index_accesses_on_account_id_and_accessed_at"
    t.index ["board_id", "user_id"], name: "index_accesses_on_board_id_and_user_id", unique: true
    t.index ["board_id"], name: "index_accesses_on_board_id"
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "account_exports", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_account_exports_on_account_id"
    t.index ["user_id"], name: "index_account_exports_on_user_id"
  end

  create_table "account_external_id_sequences", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "value", default: 0, null: false
    t.index ["value"], name: "index_account_external_id_sequences_on_value", unique: true
  end

  create_table "account_join_codes", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "usage_count", default: 0, null: false
    t.bigint "usage_limit", default: 10, null: false
    t.index ["account_id", "code"], name: "index_account_join_codes_on_account_id_and_code", unique: true
  end

  create_table "accounts", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "cards_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "external_account_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id"], name: "index_accounts_on_external_account_id", unique: true
  end

  create_table "action_text_rich_texts", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.text "body", size: :long
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_action_text_rich_texts_on_account_id"
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["account_id"], name: "index_active_storage_attachments_on_account_id"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["account_id"], name: "index_active_storage_blobs_on_account_id"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["account_id"], name: "index_active_storage_variant_records_on_account_id"
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assignees_filters", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "assignee_id", null: false
    t.uuid "filter_id", null: false
    t.index ["assignee_id"], name: "index_assignees_filters_on_assignee_id"
    t.index ["filter_id"], name: "index_assignees_filters_on_filter_id"
  end

  create_table "assigners_filters", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "assigner_id", null: false
    t.uuid "filter_id", null: false
    t.index ["assigner_id"], name: "index_assigners_filters_on_assigner_id"
    t.index ["filter_id"], name: "index_assigners_filters_on_filter_id"
  end

  create_table "assignments", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "assignee_id", null: false
    t.uuid "assigner_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_assignments_on_account_id"
    t.index ["assignee_id", "card_id"], name: "index_assignments_on_assignee_id_and_card_id", unique: true
    t.index ["card_id"], name: "index_assignments_on_card_id"
  end

  create_table "board_publications", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.index ["account_id", "key"], name: "index_board_publications_on_account_id_and_key"
    t.index ["board_id"], name: "index_board_publications_on_board_id"
  end

  create_table "boards", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "all_access", default: false, null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_boards_on_account_id"
    t.index ["creator_id"], name: "index_boards_on_creator_id"
  end

  create_table "boards_filters", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "board_id", null: false
    t.uuid "filter_id", null: false
    t.index ["board_id"], name: "index_boards_filters_on_board_id"
    t.index ["filter_id"], name: "index_boards_filters_on_filter_id"
  end

  create_table "card_activity_spikes", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_activity_spikes_on_account_id"
    t.index ["card_id"], name: "index_card_activity_spikes_on_card_id", unique: true
  end

  create_table "card_goldnesses", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_goldnesses_on_account_id"
    t.index ["card_id"], name: "index_card_goldnesses_on_card_id", unique: true
  end

  create_table "card_not_nows", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["account_id"], name: "index_card_not_nows_on_account_id"
    t.index ["card_id"], name: "index_card_not_nows_on_card_id", unique: true
    t.index ["user_id"], name: "index_card_not_nows_on_user_id"
  end

  create_table "cards", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.uuid "column_id"
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.date "due_on"
    t.datetime "last_active_at", null: false
    t.bigint "number", null: false
    t.string "status", default: "drafted", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["account_id", "last_active_at", "status"], name: "index_cards_on_account_id_and_last_active_at_and_status"
    t.index ["account_id", "number"], name: "index_cards_on_account_id_and_number", unique: true
    t.index ["board_id"], name: "index_cards_on_board_id"
    t.index ["column_id"], name: "index_cards_on_column_id"
  end

  create_table "closers_filters", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "closer_id", null: false
    t.uuid "filter_id", null: false
    t.index ["closer_id"], name: "index_closers_filters_on_closer_id"
    t.index ["filter_id"], name: "index_closers_filters_on_filter_id"
  end

  create_table "closures", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["account_id"], name: "index_closures_on_account_id"
    t.index ["card_id", "created_at"], name: "index_closures_on_card_id_and_created_at"
    t.index ["card_id"], name: "index_closures_on_card_id", unique: true
    t.index ["user_id"], name: "index_closures_on_user_id"
  end

  create_table "columns", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_columns_on_account_id"
    t.index ["board_id", "position"], name: "index_columns_on_board_id_and_position"
    t.index ["board_id"], name: "index_columns_on_board_id"
  end

  create_table "comments", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_comments_on_account_id"
    t.index ["card_id"], name: "index_comments_on_card_id"
  end

  create_table "creators_filters", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "creator_id", null: false
    t.uuid "filter_id", null: false
    t.index ["creator_id"], name: "index_creators_filters_on_creator_id"
    t.index ["filter_id"], name: "index_creators_filters_on_filter_id"
  end

  create_table "entropies", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "auto_postpone_period", default: 2592000, null: false
    t.uuid "container_id", null: false
    t.string "container_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_entropies_on_account_id"
    t.index ["container_type", "container_id", "auto_postpone_period"], name: "idx_on_container_type_container_id_auto_postpone_pe_3d79b50517"
    t.index ["container_type", "container_id"], name: "index_entropy_configurations_on_container", unique: true
  end

  create_table "events", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "action", null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.uuid "eventable_id", null: false
    t.string "eventable_type", null: false
    t.json "particulars", default: -> { "(json_object())" }
    t.datetime "updated_at", null: false
    t.index ["account_id", "action"], name: "index_events_on_account_id_and_action"
    t.index ["board_id", "action", "created_at"], name: "index_events_on_board_id_and_action_and_created_at"
    t.index ["board_id"], name: "index_events_on_board_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
  end

  create_table "filters", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.json "fields", default: -> { "(json_object())" }, null: false
    t.string "params_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_filters_on_account_id"
    t.index ["creator_id", "params_digest"], name: "index_filters_on_creator_id_and_params_digest", unique: true
  end

  create_table "filters_tags", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "filter_id", null: false
    t.uuid "tag_id", null: false
    t.index ["filter_id"], name: "index_filters_tags_on_filter_id"
    t.index ["tag_id"], name: "index_filters_tags_on_tag_id"
  end

  create_table "identities", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "staff", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
  end

  create_table "identity_access_tokens", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "identity_id", null: false
    t.string "permission"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_access_token_on_identity_id"
  end

  create_table "magic_links", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "identity_id"
    t.integer "purpose", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["identity_id"], name: "index_magic_links_on_identity_id"
  end

  create_table "mentions", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "mentionee_id", null: false
    t.uuid "mentioner_id", null: false
    t.uuid "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_mentions_on_account_id"
    t.index ["mentionee_id"], name: "index_mentions_on_mentionee_id"
    t.index ["mentioner_id"], name: "index_mentions_on_mentioner_id"
    t.index ["source_type", "source_id"], name: "index_mentions_on_source"
  end

  create_table "notification_bundles", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_notification_bundles_on_account_id"
    t.index ["ends_at", "status"], name: "index_notification_bundles_on_ends_at_and_status"
    t.index ["user_id", "starts_at", "ends_at"], name: "idx_on_user_id_starts_at_ends_at_7eae5d3ac5"
    t.index ["user_id", "status"], name: "index_notification_bundles_on_user_id_and_status"
  end

  create_table "notifications", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id"
    t.datetime "read_at"
    t.uuid "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["creator_id"], name: "index_notifications_on_creator_id"
    t.index ["source_type", "source_id"], name: "index_notifications_on_source"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_id_and_read_at_and_created_at", order: { read_at: :desc, created_at: :desc }
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "pins", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_pins_on_account_id"
    t.index ["card_id", "user_id"], name: "index_pins_on_card_id_and_user_id", unique: true
    t.index ["card_id"], name: "index_pins_on_card_id"
    t.index ["user_id"], name: "index_pins_on_user_id"
  end

  create_table "push_subscriptions", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "auth_key"
    t.datetime "created_at", null: false
    t.text "endpoint"
    t.string "p256dh_key"
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_push_subscriptions_on_account_id"
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true, length: { endpoint: 255 }
  end

  create_table "reactions", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "comment_id", null: false
    t.string "content", limit: 16, null: false
    t.datetime "created_at", null: false
    t.uuid "reacter_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_reactions_on_account_id"
    t.index ["comment_id"], name: "index_reactions_on_comment_id"
    t.index ["reacter_id"], name: "index_reactions_on_reacter_id"
  end

  create_table "search_queries", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "terms", limit: 2000, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_search_queries_on_account_id"
    t.index ["user_id", "terms"], name: "index_search_queries_on_user_id_and_terms", length: { terms: 255 }
    t.index ["user_id", "updated_at"], name: "index_search_queries_on_user_id_and_updated_at", unique: true
    t.index ["user_id"], name: "index_search_queries_on_user_id"
  end

  create_table "search_records_0", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_0_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_0_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_0_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_1", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_1_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_1_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_1_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_10", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_10_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_10_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_10_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_11", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_11_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_11_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_11_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_12", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_12_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_12_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_12_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_13", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_13_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_13_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_13_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_14", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_14_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_14_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_14_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_15", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_15_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_15_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_15_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_2", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_2_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_2_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_2_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_3", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_3_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_3_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_3_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_4", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_4_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_4_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_4_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_5", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_5_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_5_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_5_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_6", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_6_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_6_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_6_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_7", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_7_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_7_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_7_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_8", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_8_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_8_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_8_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_9", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", null: false
    t.string "title"
    t.index ["account_id"], name: "index_search_records_9_on_account_id"
    t.index ["account_key", "content", "title"], name: "index_search_records_9_on_account_key_and_content_and_title", type: :fulltext
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_9_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "sessions", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "identity_id", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  create_table "steps", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.boolean "completed", default: false, null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_steps_on_account_id"
    t.index ["card_id", "completed"], name: "index_steps_on_card_id_and_completed"
    t.index ["card_id"], name: "index_steps_on_card_id"
  end

  create_table "storage_entries", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id"
    t.uuid "board_id"
    t.datetime "created_at", null: false
    t.bigint "delta", null: false
    t.string "operation", null: false
    t.uuid "recordable_id"
    t.string "recordable_type"
    t.string "request_id"
    t.uuid "user_id"
    t.index ["account_id"], name: "index_storage_entries_on_account_id"
    t.index ["blob_id"], name: "index_storage_entries_on_blob_id"
    t.index ["board_id"], name: "index_storage_entries_on_board_id"
    t.index ["recordable_type", "recordable_id"], name: "index_storage_entries_on_recordable"
    t.index ["request_id"], name: "index_storage_entries_on_request_id"
    t.index ["user_id"], name: "index_storage_entries_on_user_id"
  end

  create_table "storage_totals", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "bytes_stored", default: 0, null: false
    t.datetime "created_at", null: false
    t.uuid "last_entry_id"
    t.uuid "owner_id", null: false
    t.string "owner_type", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_storage_totals_on_owner_type_and_owner_id", unique: true
  end

  create_table "taggings", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.uuid "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_taggings_on_account_id"
    t.index ["card_id", "tag_id"], name: "index_taggings_on_card_id_and_tag_id", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["account_id", "title"], name: "index_tags_on_account_id_and_title", unique: true
  end

  create_table "user_settings", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "bundle_email_frequency", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "timezone_name"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_user_settings_on_account_id"
    t.index ["user_id", "bundle_email_frequency"], name: "index_user_settings_on_user_id_and_bundle_email_frequency"
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.uuid "identity_id"
    t.string "name", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["account_id", "identity_id"], name: "index_users_on_account_id_and_identity_id", unique: true
    t.index ["account_id", "role"], name: "index_users_on_account_id_and_role"
    t.index ["identity_id"], name: "index_users_on_identity_id"
  end

  create_table "watches", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.boolean "watching", default: true, null: false
    t.index ["account_id"], name: "index_watches_on_account_id"
    t.index ["card_id"], name: "index_watches_on_card_id"
    t.index ["user_id", "card_id"], name: "index_watches_on_user_id_and_card_id"
    t.index ["user_id"], name: "index_watches_on_user_id"
  end

  create_table "webhook_delinquency_trackers", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "consecutive_failures_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "first_failure_at"
    t.datetime "updated_at", null: false
    t.uuid "webhook_id", null: false
    t.index ["account_id"], name: "index_webhook_delinquency_trackers_on_account_id"
    t.index ["webhook_id"], name: "index_webhook_delinquency_trackers_on_webhook_id"
  end

  create_table "webhook_deliveries", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "event_id", null: false
    t.text "request"
    t.text "response"
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.uuid "webhook_id", null: false
    t.index ["account_id"], name: "index_webhook_deliveries_on_account_id"
    t.index ["event_id"], name: "index_webhook_deliveries_on_event_id"
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "active", default: true, null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.string "signing_secret", null: false
    t.text "subscribed_actions"
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.index ["account_id"], name: "index_webhooks_on_account_id"
    t.index ["board_id", "subscribed_actions"], name: "index_webhooks_on_board_id_and_subscribed_actions", length: { subscribed_actions: 255 }
  end
end
