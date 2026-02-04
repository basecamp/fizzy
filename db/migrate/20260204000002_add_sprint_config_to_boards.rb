class AddSprintConfigToBoards < ActiveRecord::Migration[8.2]
  def change
    add_column :boards, :start_date, :date
    add_column :boards, :end_date, :date
    add_column :boards, :available_hours, :decimal, precision: 8, scale: 2
  end
end
