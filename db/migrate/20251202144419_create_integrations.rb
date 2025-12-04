class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.text :data
      t.string :type
      t.belongs_to :owner, null: false, foreign_key: false

      t.timestamps
    end
  end
end
