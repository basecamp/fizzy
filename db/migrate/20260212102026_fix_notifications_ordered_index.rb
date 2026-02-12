class FixNotificationsOrderedIndex < ActiveRecord::Migration[8.2]
  def change
    add_index :notifications, [ :user_id, :read_at, :updated_at ],
      order: { read_at: :desc, updated_at: :desc },
      name: "index_notifications_on_user_id_and_read_at_and_updated_at"
    remove_index :notifications, name: "index_notifications_on_user_id_and_read_at_and_created_at"
  end
end
