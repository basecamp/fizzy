class CreateWebhookDelinquencyTrackers < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_delinquency_trackers do |t|
      t.belongs_to :webhook, null: false, foreign_key: true
      t.datetime :last_reset_at
      t.integer :total_count, default: 0, null: false
      t.integer :failed_count, default: 0, null: false

      t.timestamps
    end
  end
end
