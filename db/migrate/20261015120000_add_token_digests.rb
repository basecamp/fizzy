# Credentials are looked up by an HMAC digest of the raw value (TokenDigester)
# rather than by the value itself. Each digest gets a unique index, created
# here, before any digest is written: a duplicate then fails loudly instead
# of indexing as two rows, and no lookup ever scans the table.
#
# One statement per change, each skipped when it's already done, so a run that
# stopped partway (MySQL commits each DDL statement on its own) can simply be
# run again. Apart, the column adds are INSTANT, and the indexes INPLACE.
class AddTokenDigests < ActiveRecord::Migration[8.2]
  def change
    add_column :identity_access_tokens, :token_digest, :string, limit: 80, if_not_exists: true
    add_column :identity_access_tokens, :refresh_token_digest, :string, limit: 80, if_not_exists: true
    add_index :identity_access_tokens, :token_digest, unique: true, if_not_exists: true
    add_index :identity_access_tokens, :refresh_token_digest, unique: true, if_not_exists: true

    add_column :oauth_clients, :client_secret_digest, :string, limit: 80, if_not_exists: true
  end
end
