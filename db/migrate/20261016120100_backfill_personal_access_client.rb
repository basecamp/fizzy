# Gives every client-less personal access token the personal access client,
# so each is a one-off access token of that first-party client, as in bc3.
# Only oauth_client_id changes: the token string, its digest, its permission
# and its lack of expiry all stay, and nothing is re-issued.
#
# update_all leaves updated_at alone. It's no lapse clock for a personal token,
# but it's what people see as the token's history, and the backfill isn't use.
#
# Rerunnable: it touches only client-less rows, and its down is a no-op (the
# client's own migration, CreatePersonalAccessClient, undoes the assignment).
# Production code that predates the client keeps writing client-less tokens,
# which every version reads as personal, so
# `db:migrate:redo:primary VERSION=20261016120100` picks them up later.
class BackfillPersonalAccessClient < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CLIENT_ID = "fizzy-personal-access"
  BATCH_SIZE = 500

  class Client < ActiveRecord::Base
    self.table_name = "oauth_clients"
  end

  class AccessToken < ActiveRecord::Base
    self.table_name = "identity_access_tokens"
  end

  def up
    client_id = Client.where(client_id: CLIENT_ID).pick(:id) or raise "#{CLIENT_ID} isn't provisioned: run CreatePersonalAccessClient first"

    AccessToken.where(oauth_client_id: nil).in_batches(of: BATCH_SIZE) do |batch|
      batch.update_all oauth_client_id: client_id
    end
  end

  def down
    # CreatePersonalAccessClient's down returns the tokens to the client-less form.
  end
end
