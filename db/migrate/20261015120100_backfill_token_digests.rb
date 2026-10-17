# Digests every stored credential that has none yet. MySQL and SQLite have no
# HMAC, so this runs in Ruby, a batch at a time, outside one long transaction.
#
# update_all writes only the digest: a grant's updated_at is its idle-lapse
# clock (Identity::AccessToken::REFRESH_IDLE_LIMIT), and backfilling must not
# restart it.
#
# Personal access tokens keep their plaintext: production still reads it until
# this code reaches it. OAuth access tokens are digest-only, so any plaintext
# one is cleared once digested. Refresh tokens and client secrets are moved
# wholesale; their plaintext columns are dropped by the next migration.
#
# Rerunnable: it only touches rows without a digest, and skips columns already
# dropped. Its down is a no-op, so `db:migrate:redo:primary VERSION=20261015120100`
# runs it again, to digest personal access tokens written since by code that
# doesn't write digests.
class BackfillTokenDigests < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  BATCH_SIZE = 500

  class AccessToken < ActiveRecord::Base
    self.table_name = "identity_access_tokens"
  end

  class Client < ActiveRecord::Base
    self.table_name = "oauth_clients"
  end

  def up
    refuse_duplicates AccessToken, :token

    each_undigested AccessToken, :token, :token_digest do |row, digest|
      AccessToken.where(id: row.id, token_digest: nil).update_all \
        token_digest: digest, token: (row.oauth_client_id ? nil : row.token)
    end

    # Gone once DropPlaintextOauthCredentials has run, so a rerun skips them.
    if column_exists?(:identity_access_tokens, :refresh_token)
      each_undigested AccessToken, :refresh_token, :refresh_token_digest do |row, digest|
        AccessToken.where(id: row.id, refresh_token_digest: nil).update_all refresh_token_digest: digest
      end
    end

    if column_exists?(:oauth_clients, :client_secret)
      each_undigested Client, :client_secret, :client_secret_digest do |row, digest|
        Client.where(id: row.id, client_secret_digest: nil).update_all client_secret_digest: digest
      end
    end
  end

  def down
    # Digests are derived from what's still stored: nothing to undo.
  end

  private
    # Two rows sharing a token would share a digest, which the unique index
    # refuses partway through. Stop before writing anything instead, naming
    # the rows but never the tokens.
    def refuse_duplicates(model, column)
      duplicated = model.where.not(column => nil).group(column).having("COUNT(*) > 1").pluck(column)

      if duplicated.any?
        ids = model.where(column => duplicated).pluck(:id)
        raise "#{model.table_name}.#{column} has #{duplicated.size} duplicated value(s), in rows #{ids.join(", ")}. Resolve them before digesting."
      end
    end

    def each_undigested(model, column, digest_column)
      model.where(digest_column => nil).where.not(column => nil).in_batches(of: BATCH_SIZE) do |batch|
        batch.select(:id, column, *(:oauth_client_id if model == AccessToken)).each do |row|
          yield row, TokenDigester.digest(row[column])
        end
      end
    end
end
