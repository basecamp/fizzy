class RemoveExternalUserIdFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :external_user_id, :integer
  end
end
