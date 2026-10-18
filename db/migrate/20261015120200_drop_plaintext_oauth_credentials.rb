# Client secrets have been digested (BackfillTokenDigests) and are never read
# in plaintext again. Nothing in production holds them: the OAuth tables have
# never served production traffic.
#
# Retired refresh tokens are only kept to recognize a replay, so the table is
# rebuilt keyed by digest rather than converted. A replay of a token rotated
# before this migration is then answered as an unknown token, not revoked.
#
# Only tables that code from before this stack never models are touched here.
# Without partial_inserts, a process names every column it has cached on each
# INSERT, so dropping a column of a table that running code writes would fail
# that code's inserts until it restarts. identity_access_tokens.refresh_token
# is such a column: Identity::AccessToken ignores it, and it is dropped beside
# `token` once every process runs code that ignores both.
class DropPlaintextOauthCredentials < ActiveRecord::Migration[8.2]
  def change
    remove_column :oauth_clients, :client_secret, :string

    drop_table :oauth_retired_refresh_tokens, id: :uuid do |t|
      t.uuid :access_token_id, null: false
      t.string :refresh_token, null: false
      t.string :successor_refresh_token, null: false
      t.datetime :created_at, null: false

      t.index :refresh_token, unique: true
      t.index :access_token_id
      t.index :created_at
    end

    create_table :oauth_retired_refresh_tokens, id: :uuid do |t|
      t.uuid :access_token_id, null: false
      t.string :refresh_token_digest, limit: 80, null: false
      t.string :successor_refresh_token_digest, limit: 80, null: false
      t.text :successor_payload
      t.datetime :created_at, null: false

      t.index :refresh_token_digest, unique: true
      t.index :access_token_id
      t.index :created_at
    end
  end
end
