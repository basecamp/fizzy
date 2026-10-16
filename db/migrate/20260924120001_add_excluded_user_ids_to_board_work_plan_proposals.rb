class AddExcludedUserIdsToBoardWorkPlanProposals < ActiveRecord::Migration[8.2]
  def change
    add_column :board_work_plan_proposals, :excluded_user_ids, :json
    change_column_null :board_work_plan_proposals, :excluded_user_ids, false, "[]"
  end
end
