class CreateUserHighlights < ActiveRecord::Migration[8.1]
  def change
    create_table :user_weekly_highlights do |t|
      t.references :user, null: false, foreign_key: true
      t.references :period_highlights, null: false, foreign_key: true
      t.date :starts_at, null: false

      t.timestamps

      t.index %i[ user_id starts_at ], unique: true
    end
  end
end
