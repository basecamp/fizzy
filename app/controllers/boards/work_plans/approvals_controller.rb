class Boards::WorkPlans::ApprovalsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    proposal = @board.work_plan_proposals.find(params.expect(:proposal_id))
    Board::WorkPlan::Apply.new(board: @board, proposal: proposal).call
    redirect_to @board, notice: "Work plan applied"
  rescue ActiveRecord::RecordNotFound
    redirect_to board_path(@board), alert: "This proposal no longer exists; plan again to review current work"
  rescue Board::WorkPlan::Apply::Error => error
    redirect_to board_path(@board), alert: "#{error.message}. Plan again to review current work"
  end
end
