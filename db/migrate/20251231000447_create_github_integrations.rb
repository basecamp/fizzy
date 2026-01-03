class CreateGithubIntegrations < ActiveRecord::Migration[8.2]
  def change
    create_table :github_integrations, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :board_id, null: false
      t.string :repository_full_name, null: false
      t.string :webhook_secret, null: false
      t.boolean :active, default: true, null: false

      # Event type toggles (per repository)
      t.boolean :sync_pull_requests, default: true, null: false
      t.boolean :sync_issues, default: true, null: false
      t.boolean :sync_comments, default: true, null: false
      t.boolean :sync_reviews, default: true, null: false

      t.timestamps

      t.index [:account_id]
      t.index [:board_id]
      t.index [:board_id, :repository_full_name], unique: true
    end
  end
end
