class CreateSessions < ActiveRecord::Migration[8.2]
  def change
    create_table "sessions", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "ip_address"
      t.datetime "updated_at", null: false
      t.string "user_agent"
      t.integer "identity_id", null: false
      t.index [ "identity_id" ], name: "index_sessions_on_identity_id"
    end

    add_foreign_key "sessions", "identities"
  end
end
