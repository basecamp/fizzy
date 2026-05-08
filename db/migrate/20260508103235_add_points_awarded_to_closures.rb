class AddPointsAwardedToClosures < ActiveRecord::Migration[8.2]
  def change
    add_column :closures, :points_awarded, :integer
  end
end
