class CreateApiTokens < ActiveRecord::Migration[8.2]
  def change
    create_table :api_tokens, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.string :name
      t.datetime :expires_at
      t.datetime :last_used_at
      t.timestamps

      t.index :token, unique: true
      t.index [:account_id, :user_id]
    end
  end
end
