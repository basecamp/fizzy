class RenameIdentityCredentialsToPasskeys < ActiveRecord::Migration[8.2]
  def change
    rename_table :identity_credentials, :passkeys
    add_column :passkeys, :holder_type, :string, null: false, default: "Identity"
    rename_column :passkeys, :identity_id, :holder_id
    change_column_default :passkeys, :holder_type, from: "Identity", to: nil
    remove_index :passkeys, :holder_id
    add_index :passkeys, [ :holder_type, :holder_id ]
  end
end
