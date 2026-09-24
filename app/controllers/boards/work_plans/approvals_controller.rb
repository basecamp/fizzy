class Boards::WorkPlans::ApprovalsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    Board::WorkPlan::Apply.new(board: @board, token: params.expect(:proposal_token)).call
    redirect_to @board, notice: "Work plan applied"
  rescue Board::WorkPlan::Apply::Error => error
    redirect_to board_path(@board), alert: "#{error.message}. Plan again to review current work"
  end
end
