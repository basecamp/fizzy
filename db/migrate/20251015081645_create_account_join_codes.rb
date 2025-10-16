class CreateAccountJoinCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :account_join_codes do |t|
      t.string :code, null: false, index: { unique: true }
      t.integer :usage_count, default: 0, null: false
      t.integer :usage_limit, default: 1, null: false
      t.belongs_to :creator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
