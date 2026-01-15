class AddUuidToActionPushNativeDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :action_push_native_devices, :uuid, :string, null: false

    remove_index :action_push_native_devices, :token
    add_index :action_push_native_devices, [ :owner_type, :owner_id, :uuid ], unique: true
  end
end
