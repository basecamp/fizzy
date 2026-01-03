class CreateAccountGithubSettings < ActiveRecord::Migration[8.2]
  def change
    create_table :account_github_settings, id: :uuid do |t|
      t.uuid :account_id, null: false

      # Global event type toggles (override per-repo settings)
      t.boolean :allow_pull_requests, default: true, null: false
      t.boolean :allow_issues, default: true, null: false
      t.boolean :allow_comments, default: true, null: false
      t.boolean :allow_reviews, default: true, null: false

      t.timestamps

      t.index [:account_id], unique: true
    end
  end
end
