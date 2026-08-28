class AddOauthClientSecrets < ActiveRecord::Migration[8.2]
  def change
    change_table :oauth_clients, bulk: true do |t|
      t.string :client_secret
      t.string :token_endpoint_auth_method, null: false, default: "none"
    end
  end
end
