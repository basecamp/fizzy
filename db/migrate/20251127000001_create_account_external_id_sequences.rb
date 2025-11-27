class CreateAccountExternalIdSequences < ActiveRecord::Migration[8.0]
  def change
    create_table :account_external_id_sequences do |t|
      t.bigint :value, null: false, default: 0

      t.index :value, unique: true
    end
  end
end
