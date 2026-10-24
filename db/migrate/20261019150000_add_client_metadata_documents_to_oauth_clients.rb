# Clients provisioned from a Client ID Metadata Document, and the document's
# HTTP caching state. Nullable column adds only (ALGORITHM=INSTANT), on a table
# that is empty in production.
class AddClientMetadataDocumentsToOauthClients < ActiveRecord::Migration[8.2]
  def change
    change_table :oauth_clients, bulk: true do |t|
      t.boolean :client_id_metadata_document, default: false
      t.datetime :metadata_fetched_at
      t.datetime :metadata_expires_at
      t.string :metadata_etag, limit: 191
    end
  end
end
