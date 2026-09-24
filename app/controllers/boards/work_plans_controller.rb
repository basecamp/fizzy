class Boards::WorkPlansController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def show
    @proposal = Board::WorkPlan::Proposal.current_for(@board) || plan_work

    render :show, status: :unprocessable_entity unless @proposal
  end

  private
    def plan_work
      request_payload = Board::WorkPlan::BuildRequest.new(board: @board).call

      if request_payload.users.empty?
        @preview_error = "No active board users available"
      elsif request_payload.candidate_work_units.empty?
        @preview_error = "No eligible cards to plan"
      else
        result = Board::WorkPlan::Solve.new(request: request_payload).call
        return Board::WorkPlan::Proposal.issue(board: @board, request: request_payload, result: result) if result.feasible?

        @preview_error = "No feasible plan was found"
      end

      nil
    rescue Board::WorkPlan::Solve::Error, Board::WorkPlan::Proposal::Invalid => error
      @preview_error = error.message
      nil
    end
end
