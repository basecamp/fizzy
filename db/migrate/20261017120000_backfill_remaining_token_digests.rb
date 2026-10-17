# Digests every access token still without one, as BackfillTokenDigests did,
# before code that finds tokens only by digest is deployed. Until then,
# production code that stores only plaintext kept writing personal access
# tokens, and each was digested only when it was first used. One never used
# since is digested here, or it would stop authenticating.
#
# MySQL and SQLite have no HMAC, so this runs in Ruby, a batch at a time,
# outside one long transaction. update_all writes only the digest: a grant's
# updated_at is its idle-lapse clock (Identity::AccessToken::REFRESH_IDLE_LIMIT),
# and backfilling must not restart it.
#
# Personal access tokens keep their plaintext, as BackfillTokenDigests left
# it, until the column is dropped, so rolling back to code that reads only
# plaintext still finds them. A personal access token is one without a
# client, or one issued by the personal access client where that client
# exists. OAuth access tokens are digest-only, so any plaintext one is
# cleared once digested.
#
# Rerunnable: it only touches rows without a digest, and does nothing once the
# plaintext column is gone. Its down is a no-op, so
# `db:migrate:redo:primary VERSION=20261017120000` runs it again.
class BackfillRemainingTokenDigests < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  BATCH_SIZE = 500

  # Identity::AccessToken ignores the plaintext column, so this reads it
  # through a model of its own.
  class AccessToken < ActiveRecord::Base
    self.table_name = "identity_access_tokens"
  end

  class Client < ActiveRecord::Base
    self.table_name = "oauth_clients"
  end

  PERSONAL_ACCESS_CLIENT_ID = "fizzy-personal-access"

  def up
    if column_exists?(:identity_access_tokens, :token)
      refuse_duplicate_tokens
      personal_client_ids = [ nil, *Client.where(client_id: PERSONAL_ACCESS_CLIENT_ID).pluck(:id) ]

      undigested.in_batches(of: BATCH_SIZE) do |batch|
        batch.select(:id, :token, :oauth_client_id).each do |row|
          AccessToken.where(id: row.id, token_digest: nil).update_all \
            token_digest: TokenDigester.digest(row.token), token: (row.oauth_client_id.in?(personal_client_ids) ? row.token : nil)
        end
      end
    end
  end

  def down
    # Digests are derived from what's still stored: nothing to undo.
  end

  private
    def undigested
      AccessToken.where(token_digest: nil).where.not(token: nil)
    end

    # Two rows sharing a token would share a digest, which the unique index
    # refuses partway through. Stop before writing anything instead, naming
    # the rows but never the tokens.
    def refuse_duplicate_tokens
      duplicated = AccessToken.where.not(token: nil).group(:token).having("COUNT(*) > 1").pluck(:token)

      if duplicated.any?
        ids = AccessToken.where(token: duplicated).pluck(:id)
        raise "identity_access_tokens.token has #{duplicated.size} duplicated value(s), in rows #{ids.join(", ")}. Resolve them before digesting."
      end
    end
end
