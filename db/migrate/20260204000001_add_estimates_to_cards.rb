class AddEstimatesToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :business_value, :integer
    add_column :cards, :difficulty, :integer
    add_column :cards, :estimate_hours, :decimal, precision: 8, scale: 2
  end
end
