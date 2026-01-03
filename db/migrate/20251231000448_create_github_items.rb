class CreateGithubItems < ActiveRecord::Migration[8.2]
  def change
    create_table :github_items, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id, null: false
      t.uuid :github_integration_id, null: false

      # GitHub identifiers
      t.bigint :github_id, null: false
      t.string :github_type, null: false
      t.string :github_url, null: false
      t.integer :github_number, null: false

      # Cached metadata
      t.string :state
      t.datetime :last_synced_at

      t.timestamps

      t.index [:account_id]
      t.index [:card_id], unique: true
      t.index [:github_integration_id, :github_id], unique: true
      t.index [:github_integration_id, :github_type, :github_number]
    end
  end
end
