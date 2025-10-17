class CreateAccountJoinCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :account_join_codes do |t|
      t.string :code, null: false, index: { unique: true }
      t.integer :usage_count, default: 0, null: false
      t.integer :usage_limit, default: 10, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO account_join_codes (code, usage_count, usage_limit, created_at, updated_at)
          SELECT join_code, 0, 10, datetime('now'), datetime('now')
          FROM accounts
          WHERE join_code IS NOT NULL;
        SQL
      end

      dir.down do
      end
    end
  end
end
