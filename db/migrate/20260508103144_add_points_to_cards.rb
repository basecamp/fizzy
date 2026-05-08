class AddPointsToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :points, :integer
  end
end
