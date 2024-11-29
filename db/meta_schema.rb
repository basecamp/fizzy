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

ActiveRecord::Schema[8.0].define(version: 2024_11_29_152805) do
  create_table "tenants", force: :cascade do |t|
    t.string "slug"
    t.string "dbname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dbname"], name: "index_tenants_on_dbname", unique: true
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
  end
end
