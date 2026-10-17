# Drops the plaintext personal access tokens that BackfillTokenDigests and
# BackfillRemainingTokenDigests left beside their digests.
#
# Run it only once every process runs the code that shipped with
# BackfillRemainingTokenDigests, or later. That code finds tokens only by
# digest and ignores this column, so it never names it. Code from before it
# still writes personal access tokens' plaintext, and falls back to reading
# it, so it fails once the column is gone.
#
# Undoing this restores the column empty and nullable, as it was before any
# token was written. The tokens it held can't be recovered from their
# digests, so code that reads only plaintext can't authenticate them again.
class DropIdentityAccessTokenPlaintext < ActiveRecord::Migration[8.2]
  def up
    if connection.adapter_name.in?(%w[ Mysql2 Trilogy ])
      # MySQL would drop the column INSTANT, from the data dictionary alone,
      # leaving each row's plaintext in the table's pages until that row is
      # next rewritten, which for most tokens is never. Rebuilding the table
      # writes every row without it, still without blocking reads or writes.
      execute "ALTER TABLE identity_access_tokens DROP COLUMN token, ALGORITHM=INPLACE, LOCK=NONE"
    else
      remove_column :identity_access_tokens, :token
    end
  end

  def down
    add_column :identity_access_tokens, :token, :string
  end
end
