class AddVerifiedAtToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :verified_at, :datetime
  end
end
