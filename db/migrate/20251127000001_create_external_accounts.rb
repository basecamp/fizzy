class CreateExternalAccounts < ActiveRecord::Migration[8.0]
  def up
    create_table :external_accounts do |t|
    end

    max_id = Account.maximum(:external_account_id) || 0
    if max_id > 0
      execute "INSERT INTO external_accounts (id) VALUES (#{max_id})"
    end
  end

  def down
    drop_table :external_accounts
  end
end
