class BringBackProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :creator, null: false
      t.string :name, null: false

      t.timestamps
    end
  end
end
