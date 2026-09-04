class AddOauthTokenExpiry < ActiveRecord::Migration[8.2]
  def change
    change_table :identity_access_tokens, bulk: true do |t|
      t.string :refresh_token
      t.datetime :expires_at

      t.index :refresh_token, unique: true
    end
  end
end
