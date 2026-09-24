class Boards::WorkPlansController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board
  before_action :set_board_work_plan_request, only: [ :preview, :apply ]

  def preview
    if request_payload.users.empty? || request_payload.candidate_work_units.empty?
      @preview_error = request_payload.users.empty? ? "No active board users available" : "No eligible cards to plan"
      render :preview, status: :unprocessable_entity
      return
    end

    @solve_result = Board::WorkPlan::Solve.new(request: request_payload).call

    unless feasible_solution?(@solve_result)
      @preview_error = "No feasible plan was found"
      render :preview, status: :unprocessable_entity
      return
    end

    @plan = parse_plan(@solve_result)

    render :preview
  rescue Board::WorkPlan::Solve::Error => error
    @preview_error = error.message
    render :preview, status: :unprocessable_entity
  end

  def apply
    @plan = parse_plan_from_params
    Board::WorkPlan::Apply.new(board: @board, plan: apply_plan_params).call

    respond_to do |format|
      format.html do
        redirect_to @board, notice: "Work plan applied"
      end
    end
  rescue Board::WorkPlan::Apply::Error => error
    @preview_error = error.message
    @solve_result = OpenStruct.new(proposed_assignments: Array(@plan[:proposed_assignments]).map(&:deep_symbolize_keys))
    render :preview, status: :unprocessable_entity
  end

  private
    attr_reader :request_payload

    def feasible_solution?(solve_result)
      return false if solve_result.blank?

      return solve_result.feasible? if solve_result.respond_to?(:feasible?)

      solve_result.status.to_s == "feasible"
    end

    def set_board_work_plan_request
      @request_payload = Board::WorkPlan::BuildRequest.new(board: @board).call
    end

    def parse_plan(solve_result)
      {
        based_on_board_updated_at: @board.updated_at.iso8601(6),
        proposed_assignments: solve_result.proposed_assignments
      }
    end

    def parse_plan_from_params
      {
        based_on_board_updated_at: apply_plan_params[:based_on_board_updated_at],
        proposed_assignments: normalized_proposed_assignments(apply_plan_params)
      }
    end

    def normalized_proposed_assignments(params)
      Array(params[:proposed_assignments]).map do |proposal|
        proposal = proposal.to_unsafe_h if proposal.respond_to?(:to_unsafe_h)
        {
          card_id: proposal[:card_id].to_s,
          assignee_id: proposal[:assignee_id].to_s
        }
      end
    end

    def apply_plan_params
      params.require(:plan).permit(:based_on_board_updated_at, proposed_assignments: [ :card_id, :assignee_id ])
    end
end
