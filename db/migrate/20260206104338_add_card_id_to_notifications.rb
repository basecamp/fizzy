class AddCardIdToNotifications < ActiveRecord::Migration[8.2]
  def change
    add_column :notifications, :card_id, :uuid
    add_column :notifications, :unread_count, :integer, null: false, default: 0
  end
end
