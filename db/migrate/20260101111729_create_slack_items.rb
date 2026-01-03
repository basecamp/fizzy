class CreateSlackItems < ActiveRecord::Migration[8.2]
  def change
    create_table :slack_items, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id, null: false
      t.uuid :slack_integration_id, null: false

      # Slack identifiers
      t.string :slack_message_ts, null: false
      t.string :slack_user_id
      t.string :channel_id, null: false

      # Cached metadata
      t.datetime :last_synced_at

      t.timestamps

      t.index [:account_id]
      t.index [:card_id], unique: true
      t.index [:slack_integration_id, :slack_message_ts], unique: true
      t.index [:channel_id]
    end
  end
end
