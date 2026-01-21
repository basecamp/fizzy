class AddSessionToActionPushNativeDevices < ActiveRecord::Migration[8.2]
  def change
    add_reference :action_push_native_devices, :session, foreign_key: true, type: :uuid
  end
end
