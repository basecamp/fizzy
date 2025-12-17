class CreateAccountBillingWaivers < ActiveRecord::Migration[8.2]
  def change
    create_table :account_billing_waivers, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: { unique: true }

      t.timestamps
    end
  end
end
