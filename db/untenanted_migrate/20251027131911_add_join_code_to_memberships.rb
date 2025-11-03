class AddJoinCodeToMemberships < ActiveRecord::Migration[8.2]
  def change
    add_column :memberships, :join_code, :string
  end
end
