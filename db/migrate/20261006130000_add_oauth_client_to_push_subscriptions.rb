class AddOauthClientToPushSubscriptions < ActiveRecord::Migration[8.2]
  def change
    add_reference :push_subscriptions, :oauth_client, type: :uuid, foreign_key: false
  end
end
