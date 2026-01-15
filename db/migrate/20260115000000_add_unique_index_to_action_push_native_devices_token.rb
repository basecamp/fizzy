class AddUniqueIndexToActionPushNativeDevicesToken < ActiveRecord::Migration[8.0]
  def change
    add_index :action_push_native_devices, :token, unique: true
  end
end
