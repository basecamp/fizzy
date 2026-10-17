# Provisions the first-party client that issues personal access tokens
# (Oauth::Client::PERSONAL_ACCESS_CLIENT_ID), on every install that migrates,
# SaaS or self-hosted. Oauth::Client.personal_access_issuer makes it on first
# use where the schema was loaded instead. It's never registered, so the sweep
# of abandoned registrations passes it by.
#
# Down hands its tokens back to the client-less form, which every version of
# the code reads as personal, and then removes it. Neither direction moves
# updated_at. Run it only once no code with the client is serving: that code
# issues the client's tokens, takes no lock doing so, and makes the client
# again on first use, so nothing down could do would keep up with it. With
# that settled, the order makes down safe to retry: the client stays until
# every token is handed back, so a down that stops partway finds it again.
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
      AccessToken.where(oauth_client_id: client.id).in_batches(of: BATCH_SIZE) do |batch|
        batch.update_all oauth_client_id: nil
      end

      client.delete
    end
  end
end
