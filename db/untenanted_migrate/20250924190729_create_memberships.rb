class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.string :email_address, null: false
      t.references :identity, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: false, index: false
      t.string :user_tenant, null: false
      t.string :account_name, null: false

      t.timestamps
    end
    add_index :memberships, :email_address
    add_index :memberships, [ :user_tenant, :user_id ]
  end
end
