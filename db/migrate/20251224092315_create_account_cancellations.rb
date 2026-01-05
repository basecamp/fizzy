class CreateAccountCancellations < ActiveRecord::Migration[8.2]
  def change
    create_table :account_cancellations, id: :uuid do |t|
      t.uuid :account_id, null: false, index: { unique: true }
      t.uuid :initiated_by_id, null: false

      t.timestamps
    end
  end
end
