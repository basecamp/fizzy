class RemoveRedundantOwnerIndexFromActionPushNativeDevices < ActiveRecord::Migration[8.2]
  def change
    remove_index :action_push_native_devices, column: [ :owner_type, :owner_id ]
  end
end
