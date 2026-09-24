class Boards::WorkPlans::ProposalsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    Board::WorkPlan::Proposal.plan(board: @board, user_ids: params.expect(user_ids: []).reject(&:blank?).uniq)
    redirect_to board_work_plan_path(@board), status: :see_other
  rescue Board::WorkPlan::Solve::Error, Board::WorkPlan::Proposal::Invalid => error
    redirect_to board_work_plan_path(@board), flash: { work_plan_error: error.message }, status: :see_other
  end
end
