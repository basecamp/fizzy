class CreateAccountSlackSettings < ActiveRecord::Migration[8.2]
  def change
    create_table :account_slack_settings, id: :uuid do |t|
      t.uuid :account_id, null: false

      # Global event type toggles (override per-channel settings)
      t.boolean :allow_messages, default: true, null: false
      t.boolean :allow_thread_replies, default: true, null: false
      t.boolean :allow_reactions, default: true, null: false

      t.timestamps

      t.index [:account_id], unique: true
    end
  end
end
