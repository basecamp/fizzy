# Each step is skipped when it's already done, so a run that stopped partway
# (MySQL commits each DDL statement on its own) can simply be run again.
class AddOauth < ActiveRecord::Migration[8.2]
  def change
    create_table :oauth_clients, id: :uuid, if_not_exists: true do |t|
      t.string :client_id, null: false
      t.string :name, null: false
      t.json :redirect_uris
      t.json :scopes
      t.boolean :trusted, default: false
      t.boolean :dynamically_registered, default: false

      t.timestamps

      t.index :client_id, unique: true
    end

    add_reference :identity_access_tokens, :oauth_client, type: :uuid, foreign_key: false, if_not_exists: true
  end
end
