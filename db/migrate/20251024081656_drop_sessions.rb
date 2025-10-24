class DropSessions < ActiveRecord::Migration[8.2]
  def up
    drop_table :sessions
  end

  def down
    create_table "sessions", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "ip_address"
      t.datetime "updated_at", null: false
      t.string "user_agent"
      t.integer "user_id", null: false
      t.index ["user_id"], name: "index_sessions_on_user_id"
    end

    add_foreign_key "sessions", "users"
  end
end
