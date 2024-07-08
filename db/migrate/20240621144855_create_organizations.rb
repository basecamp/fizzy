class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.citext :name, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
