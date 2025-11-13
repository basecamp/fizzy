class DropMemberships < ActiveRecord::Migration[8.2]
  def change
    add_reference :users, :identity, type: :uuid, null: true, foreign_key: true
    remove_column :users, :membership_id, :bigint
    drop_table :memberships
  end
end
