class AddManualSortingEnabledToBoards < ActiveRecord::Migration[8.2]
  def change
    add_column :boards, :manual_sorting_enabled, :boolean, default: false, null: false
  end
end

