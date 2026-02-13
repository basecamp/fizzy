class CreateIdentityCredentials < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_credentials, id: :uuid do |t|
      t.uuid :identity_id, null: false
      t.string :credential_id, null: false
      t.binary :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.text :transports

      t.timestamps

      t.index :identity_id
      t.index :credential_id, unique: true
    end
  end
end
