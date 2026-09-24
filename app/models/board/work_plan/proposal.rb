module Board::WorkPlan
  class Proposal < ApplicationRecord
    class Invalid < StandardError; end

    self.table_name = "board_work_plan_proposals"

    belongs_to :account, default: -> { board.account }
    belongs_to :board
    belongs_to :creator, class_name: "User"

    has_many :assignments, -> { ordered.preload(card: [ :goldness, :activity_spike ]) },
      class_name: "Board::WorkPlan::Proposal::Assignment", inverse_of: :proposal, dependent: :delete_all

    scope :recent_first, -> { order(created_at: :desc) }

    class << self
      def current_for(board)
        proposal = where(board: board).recent_first.first
        proposal if proposal&.current?
      end

      def issue(board:, request:, result:, user: Current.user)
        assignments = result.proposed_assignments

        unless result.feasible? && assignments.map { |assignment| assignment.fetch(:card_id) }.sort == request.candidate_card_ids.sort &&
            assignments.all? { |assignment| request.users_by_id.key?(assignment.fetch(:assignee_id)) }
          raise Invalid, "The planner returned an incomplete proposal"
        end

        transaction do
          discard_proposals_for(board)
          proposal = create!(board: board, creator: user, board_updated_at: board.updated_at)
          proposal.assignments.insert_all(
            assignments.each_with_index.map do |assignment, position|
              {
                id: ActiveRecord::Type::Uuid.generate,
                account_id: board.account_id,
                proposal_id: proposal.id,
                card_id: assignment.fetch(:card_id),
                assignee_id: assignment.fetch(:assignee_id),
                position: position,
                created_at: Time.current,
                updated_at: Time.current
              }
            end
          )
          proposal
        end
      end

      private
        # A board only ever needs its latest plan; older ones are dead weight.
        def discard_proposals_for(board)
          Proposal::Assignment.where(proposal_id: board.work_plan_proposals.select(:id)).delete_all
          board.work_plan_proposals.delete_all
        end
    end

    def current?
      board_updated_at.iso8601(6) == board.updated_at.iso8601(6)
    end
  end
end
