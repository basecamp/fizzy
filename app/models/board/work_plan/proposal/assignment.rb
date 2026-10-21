module Board::WorkPlan
  class Proposal
    class Assignment < ApplicationRecord
      self.table_name = "board_work_plan_proposal_assignments"

      belongs_to :proposal, class_name: "Board::WorkPlan::Proposal", inverse_of: :assignments
      belongs_to :card
      belongs_to :assignee, class_name: "User"

      scope :ordered, -> { order(:assignee_id, :position) }
    end
  end
end
