class CreatePasskeys < ActiveRecord::Migration[8.2]
  def change
    create_table :passkeys, id: :uuid do |t|
      t.references :identity, null: false, foreign_key: true, type: :uuid
      t.string :external_id, null: false
      t.binary :public_key, null: false
      t.bigint :sign_count, default: 0, null: false
      t.string :name
      t.timestamps
    end

    add_index :passkeys, :external_id, unique: true
  end
end
