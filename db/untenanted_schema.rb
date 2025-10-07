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

ActiveRecord::Schema[8.1].define(version: 2025_10_07_112917) do
  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "magic_links", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "membership_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["membership_id"], name: "index_magic_links_on_membership_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.string "account_name", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "identity_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "user_tenant", null: false
    t.index ["email_address"], name: "index_memberships_on_email_address"
    t.index ["identity_id"], name: "index_memberships_on_identity_id"
    t.index ["user_tenant", "user_id"], name: "index_memberships_on_user_tenant_and_user_id"
  end

  add_foreign_key "magic_links", "memberships"
  add_foreign_key "memberships", "identities"
end
