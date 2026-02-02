class AddNextAmountDueInCentsToAccountSubscriptions < ActiveRecord::Migration[8.2]
  def change
    add_column :account_subscriptions, :next_amount_due_in_cents, :integer
  end
end
