class CreateIdentityAccessTokens < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_access_tokens, id: :uuid do |t|
      t.uuid :identity_id, null: false
      t.string :token
      t.string :permission
      t.text :description

      t.timestamps

      t.index ["identity_id"], name: "index_access_token_on_identity_id"
    end
  end
end
