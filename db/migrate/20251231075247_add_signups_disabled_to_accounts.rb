class AddSignupsDisabledToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :signups_disabled, :boolean, default: false, null: false
  end
end
