class AddContextToMemberships < ActiveRecord::Migration[8.2]
  def change
    add_column :memberships, :context, :text
  end
end
