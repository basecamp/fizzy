# Each step is skipped when it's already done, so a run that stopped partway
# (MySQL commits each DDL statement on its own) can simply be run again.
class AddOauthClientToPushSubscriptions < ActiveRecord::Migration[8.2]
  def change
    add_reference :push_subscriptions, :oauth_client, type: :uuid, foreign_key: false, if_not_exists: true
  end
end
