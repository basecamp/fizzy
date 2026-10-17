# Credentials are looked up by an HMAC digest of the raw value (TokenDigester)
# rather than by the value itself. Each digest gets a unique index, created
# here, before any digest is written: a duplicate then fails loudly instead
# of indexing as two rows, and no lookup ever scans the table.
class AddTokenDigests < ActiveRecord::Migration[8.2]
  def change
    change_table :identity_access_tokens, bulk: true do |t|
      t.string :token_digest, limit: 80
      t.string :refresh_token_digest, limit: 80

      t.index :token_digest, unique: true
      t.index :refresh_token_digest, unique: true
    end

    add_column :oauth_clients, :client_secret_digest, :string, limit: 80
  end
end
