class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.string :slug
      t.string :dbname

      t.timestamps
    end
    add_index :tenants, :slug, unique: true
    add_index :tenants, :dbname, unique: true
  end
end
