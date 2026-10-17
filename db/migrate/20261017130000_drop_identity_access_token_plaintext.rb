# Drops the plaintext personal access tokens that BackfillTokenDigests and
# BackfillRemainingTokenDigests left beside their digests. Tokens are found
# only by digest, and Identity::AccessToken has ignored this column since
# those backfills, so no process running that code names it.
#
# Undoing this restores the column empty and nullable, as it was before any
# token was written. The tokens it held can't be recovered from their
# digests, so code that reads only plaintext can't authenticate them again.
class DropIdentityAccessTokenPlaintext < ActiveRecord::Migration[8.2]
  def change
    remove_column :identity_access_tokens, :token, :string
  end
end
