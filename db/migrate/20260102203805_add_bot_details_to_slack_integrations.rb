class AddBotDetailsToSlackIntegrations < ActiveRecord::Migration[8.2]
  def change
    add_column :slack_integrations, :bot_user_id, :string
    add_column :slack_integrations, :bot_oauth_token, :string
  end
end
