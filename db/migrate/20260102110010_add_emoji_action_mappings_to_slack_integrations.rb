class AddEmojiActionMappingsToSlackIntegrations < ActiveRecord::Migration[8.2]
  def change
    add_column :slack_integrations, :emoji_action_mappings, :json
  end
end
