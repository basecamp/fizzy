class CreateBoardWorkPlanProposals < ActiveRecord::Migration[8.2]
  def change
    create_table :board_work_plan_proposals, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :board_id, null: false
      t.uuid :creator_id, null: false
      t.datetime :board_updated_at, null: false

      t.timestamps

      t.index [ :board_id, :created_at ]
    end

    create_table :board_work_plan_proposal_assignments, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :proposal_id, null: false
      t.uuid :card_id, null: false
      t.uuid :assignee_id, null: false
      t.integer :position, null: false, default: 0

      t.timestamps

      t.index [ :proposal_id, :assignee_id, :position ]
    end
  end
end
