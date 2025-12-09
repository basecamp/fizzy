class CreateStorageTables < ActiveRecord::Migration[8.0]
  def change
    # Storage ledger: debit/credit event stream
    create_table :storage_entries, id: :uuid do |t|
      t.references :account, type: :uuid, null: false
      t.references :board, type: :uuid, null: true

      t.references :recordable, type: :uuid, polymorphic: true, null: true

      t.bigint :delta, null: false
      t.string :operation, null: false

      t.datetime :created_at, null: false
    end

    # Storage totals: cached snapshots
    create_table :storage_totals, id: :uuid do |t|
      t.references :owner, type: :uuid, polymorphic: true, null: false, index: false

      t.bigint :bytes_stored, null: false, default: 0
      t.uuid :last_entry_id  # Cursor: includes all entries <= this ID

      t.timestamps
      t.index %i[ owner_type owner_id ], unique: true
    end
  end
end
