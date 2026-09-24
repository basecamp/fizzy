class Boards::WorkPlansController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def show
    return render_proposal if turbo_frame_request?

    @eligible_users = @board.users.active.alphabetically
    @proposal = Board::WorkPlan::Proposal.current_for(@board)
    @excluded_user_ids = @proposal&.excluded_user_ids || []
  end

  private
    def render_proposal
      @preview_error = flash[:work_plan_error]
      @proposal = Board::WorkPlan::Proposal.current_for(@board) unless @preview_error

      if @proposal
        set_page_and_extract_portion_from @proposal.assignments
        @assignee_card_counts = @proposal.assignments.group(:assignee_id).count

        if @page.number > 1 && (first = @page.records.first)
          @continuing_assignee_id = first.assignee_id if @proposal.assignments.where(assignee_id: first.assignee_id)
            .where("position < ?", first.position).exists?
        end
      end

      render partial: "proposal"
    end
end
