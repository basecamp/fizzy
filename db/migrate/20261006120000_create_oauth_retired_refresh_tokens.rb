class CreateOauthRetiredRefreshTokens < ActiveRecord::Migration[8.2]
  def change
    create_table :oauth_retired_refresh_tokens, id: :uuid do |t|
      t.uuid :access_token_id, null: false
      t.string :refresh_token, null: false
      t.datetime :created_at, null: false

      t.index :refresh_token, unique: true
      t.index [ :access_token_id, :created_at ], name: "index_oauth_retired_refresh_tokens_on_access_token_id"
      t.index :created_at
    end
  end
end
