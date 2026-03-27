class DropBillingTables < ActiveRecord::Migration[8.2]
  def change
    drop_table :account_subscriptions
    drop_table :account_overridden_limits
    drop_table :account_billing_waivers
  end
end
