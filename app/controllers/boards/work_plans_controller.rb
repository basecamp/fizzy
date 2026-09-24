class Boards::WorkPlansController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def show
    @request_payload = Board::WorkPlan::BuildRequest.new(board: @board).call
    @assignees_by_id = @board.users.active.index_by { |user| user.id.to_s }

    if request_payload.users.empty? || request_payload.candidate_work_units.empty?
      @preview_error = request_payload.users.empty? ? "No active board users available" : "No eligible cards to plan"
      render :show, status: :unprocessable_entity
      return
    end

    @solve_result = Board::WorkPlan::Solve.new(request: request_payload).call

    if @solve_result.feasible?
      @proposal_token = Board::WorkPlan::Proposal.issue(board: @board, request: request_payload, result: @solve_result)
    else
      @preview_error = "No feasible plan was found"
      render :show, status: :unprocessable_entity
    end
  rescue Board::WorkPlan::Solve::Error, Board::WorkPlan::Proposal::Invalid => error
    @preview_error = error.message
    render :show, status: :unprocessable_entity
  end

  private
    attr_reader :request_payload
end
