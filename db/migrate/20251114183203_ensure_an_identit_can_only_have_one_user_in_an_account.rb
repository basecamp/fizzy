class EnsureAnIdentitCanOnlyHaveOneUserInAnAccount < ActiveRecord::Migration[8.2]
  def change
    add_index :users, [:account_id, :identity_id], unique: true
  end
end
