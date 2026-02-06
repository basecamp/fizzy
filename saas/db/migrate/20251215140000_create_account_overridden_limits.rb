class CreateAccountOverriddenLimits < ActiveRecord::Migration[8.2]
  def change
    create_table :account_overridden_limits, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: { unique: true }
      t.integer :card_count

      t.timestamps
    end
  end
end
