class AddRemainingHoursToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :remaining_hours, :decimal, precision: 8, scale: 2
  end
end
