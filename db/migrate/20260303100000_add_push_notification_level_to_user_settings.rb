class AddPushNotificationLevelToUserSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :user_settings, :push_notification_level, :integer, default: 0, null: false
  end
end
