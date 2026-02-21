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

ActiveRecord::Schema[8.2].define(version: 2026_01_26_230838) do
  create_table "account_billing_waivers", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_billing_waivers_on_account_id", unique: true
  end

  create_table "account_overridden_limits", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "bytes_used"
    t.integer "card_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_overridden_limits_on_account_id", unique: true
  end

  create_table "account_subscriptions", id: :uuid, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "cancel_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.integer "next_amount_due_in_cents"
    t.string "plan_key"
    t.string "status"
    t.string "stripe_customer_id", null: false
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_subscriptions_on_account_id"
    t.index ["stripe_customer_id"], name: "index_account_subscriptions_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_account_subscriptions_on_stripe_subscription_id", unique: true
  end

  create_table "action_push_native_devices", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.uuid "owner_id"
    t.string "owner_type"
    t.string "platform", null: false
    t.uuid "session_id"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "token"], name: "idx_on_owner_type_owner_id_token_95a4008c64", unique: true
    t.index ["session_id"], name: "index_action_push_native_devices_on_session_id"
  end

  create_table "audits1984_auditor_tokens", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "auditor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["auditor_id"], name: "index_audits1984_auditor_tokens_on_auditor_id", unique: true
    t.index ["token_digest"], name: "index_audits1984_auditor_tokens_on_token_digest", unique: true
  end

  create_table "audits1984_audits", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.uuid "auditor_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "session_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_audits1984_audits_on_session_id"
  end

  create_table "console1984_commands", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "sensitive_access_id"
    t.bigint "session_id", null: false
    t.text "statements"
    t.datetime "updated_at", null: false
    t.index ["sensitive_access_id"], name: "index_console1984_commands_on_sensitive_access_id"
    t.index ["session_id", "created_at", "sensitive_access_id"], name: "on_session_and_sensitive_chronologically"
  end

  create_table "console1984_sensitive_accesses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "justification"
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_console1984_sensitive_accesses_on_session_id"
  end

  create_table "console1984_sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_console1984_sessions_on_created_at"
    t.index ["user_id", "created_at"], name: "index_console1984_sessions_on_user_id_and_created_at"
  end

  create_table "console1984_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_console1984_users_on_username"
  end
end
