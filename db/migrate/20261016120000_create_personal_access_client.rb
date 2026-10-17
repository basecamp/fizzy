# Provisions the first-party client that issues personal access tokens
# (Oauth::Client::PERSONAL_ACCESS_CLIENT_ID), on every install that migrates,
# SaaS or self-hosted. Oauth::Client.personal_access_issuer makes it on first
# use where the schema was loaded instead. It's never registered, so the sweep
# of abandoned registrations passes it by.
#
# Down removes it and hands its tokens back to the client-less form, which
# every version of the code reads as personal. Neither direction moves
# updated_at. Run it once code that doesn't know the client is deployed:
# code that does keeps issuing the client's tokens, and makes the client
# again on first use. The client goes first, so only a request that looked
# it up before then can still issue one of its tokens, and the batches repeat
# until none is left naming a client that's gone.
class CreatePersonalAccessClient < ActiveRecord::Migration[8.2]
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
    unless Client.exists?(client_id: CLIENT_ID)
      Client.create! client_id: CLIENT_ID, name: "Personal Access Tokens", trusted: true, dynamically_registered: false,
        redirect_uris: [], scopes: %w[ read write ], token_endpoint_auth_method: "none"
    end
  end

  def down
    if client = Client.find_by(client_id: CLIENT_ID)
      client.delete

      tokens = AccessToken.where(oauth_client_id: client.id)

      while tokens.exists?
        tokens.in_batches(of: BATCH_SIZE) { |batch| batch.update_all oauth_client_id: nil }
      end
    end
  end
end
