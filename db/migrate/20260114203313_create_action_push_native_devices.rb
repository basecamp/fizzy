class CreateActionPushNativeDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :action_push_native_devices do |t|
      t.string :uuid, null: false
      t.string :name
      t.string :platform, null: false
      t.string :token, null: false
      t.belongs_to :owner, polymorphic: true, type: :uuid

      t.timestamps
    end

    add_index :action_push_native_devices, [ :owner_type, :owner_id, :uuid ], unique: true
  end
end
