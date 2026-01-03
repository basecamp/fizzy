class CreateSlackIntegrations < ActiveRecord::Migration[8.2]
  def change
    create_table :slack_integrations, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :board_id, null: false
      t.string :channel_id, null: false
      t.string :channel_name, null: false
      t.string :workspace_domain
      t.string :webhook_secret, null: false
      t.boolean :active, default: true, null: false
      t.string :color

      # Event type toggles (per channel)
      t.boolean :sync_messages, default: true, null: false
      t.boolean :sync_thread_replies, default: true, null: false
      t.boolean :sync_reactions, default: true, null: false

      t.timestamps

      t.index [:account_id]
      t.index [:board_id]
      t.index [:board_id, :channel_id], unique: true
    end
  end
end
