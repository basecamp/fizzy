class AddSetupStatusToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :setup_status, :string
  end
end
