# Drops the plaintext personal access tokens that BackfillTokenDigests and
# BackfillRemainingTokenDigests left beside their digests, and the plaintext
# refresh token column, empty since BackfillTokenDigests.
#
# Run it only once every process runs the code that shipped with
# BackfillRemainingTokenDigests, or later. That code finds tokens only by
# digest and ignores both columns, so it never names them. Code from before it
# still writes personal access tokens' plaintext, and falls back to reading
# it, so it fails once the column is gone. Code from before
# DropPlaintextOauthCredentials, which doesn't ignore refresh_token, names it
# on every INSERT.
#
# Undoing this restores both columns empty and nullable, as they were before
# any token was written. The tokens they held can't be recovered from their
# digests, so code that reads only plaintext can't authenticate them again.
class DropIdentityAccessTokenPlaintext < ActiveRecord::Migration[8.2]
  def up
    if connection.adapter_name.in?(%w[ Mysql2 Trilogy ])
      # MySQL would drop the columns INSTANT, from the data dictionary alone,
      # leaving each row's plaintext in the table's pages until that row is
      # next rewritten, which for most tokens is never. Rebuilding the table
      # writes every row without them, still without blocking reads or writes.
      execute "ALTER TABLE identity_access_tokens DROP INDEX index_identity_access_tokens_on_refresh_token, " \
        "DROP COLUMN refresh_token, DROP COLUMN token, ALGORITHM=INPLACE, LOCK=NONE"
    else
      remove_index :identity_access_tokens, :refresh_token, unique: true
      remove_column :identity_access_tokens, :refresh_token
      remove_column :identity_access_tokens, :token
    end
  end

  def down
    add_column :identity_access_tokens, :token, :string
    add_column :identity_access_tokens, :refresh_token, :string
    add_index :identity_access_tokens, :refresh_token, unique: true
  end
end
