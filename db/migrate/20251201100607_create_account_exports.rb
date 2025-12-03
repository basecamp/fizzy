class CreateAccountExports < ActiveRecord::Migration[8.2]
  def change
    create_table :account_exports, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :user_id, null: false
      t.string :status, default: "pending", null: false
      t.datetime :completed_at
      t.timestamps

      t.index :account_id
      t.index :user_id
    end
  end
end
