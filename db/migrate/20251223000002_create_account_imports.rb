class CreateAccountImports < ActiveRecord::Migration[8.2]
  def change
    create_table :account_imports, id: :uuid do |t|
      t.uuid :identity_id, null: false
      t.uuid :account_id
      t.string :status, default: "pending", null: false
      t.datetime :completed_at
      t.timestamps

      t.index :identity_id
      t.index :account_id
    end
  end
end
