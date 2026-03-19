class CreateAccountStorageExceptions < ActiveRecord::Migration[8.2]
  def change
    create_table :account_storage_exceptions, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: { unique: true }
      t.bigint :bytes_allowed, null: false

      t.timestamps
    end
  end
end
