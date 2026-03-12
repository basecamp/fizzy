class CreateActionPackPasskeys < ActiveRecord::Migration[8.2]
  def change
    create_table :action_pack_passkeys, id: :uuid do |t|
      t.uuid :holder_id, null: false
      t.string :holder_type, null: false
      t.string :credential_id, null: false
      t.binary :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :name
      t.text :transports
      t.string :aaguid
      t.boolean :backed_up

      t.timestamps

      t.index [ :holder_type, :holder_id ]
      t.index :credential_id, unique: true
    end
  end
end
