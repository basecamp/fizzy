class AddWorkPlanningTimeLimitInSecondsToBoards < ActiveRecord::Migration[8.2]
  def change
    add_column :boards, :work_planning_time_limit_in_seconds, :integer, default: 30, null: false
  end
end
