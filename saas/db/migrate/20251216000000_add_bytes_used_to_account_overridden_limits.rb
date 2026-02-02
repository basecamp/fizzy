class AddBytesUsedToAccountOverriddenLimits < ActiveRecord::Migration[8.2]
  def change
    add_column :account_overridden_limits, :bytes_used, :bigint
  end
end
