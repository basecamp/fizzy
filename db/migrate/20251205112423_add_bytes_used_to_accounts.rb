class AddBytesUsedToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :bytes_used, :bigint, default: 0
  end
end
