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
      def plan(board:, user_ids:, user: Current.user)
        planned_at = board.updated_at
        board_user_ids = board.users.active.ids.map(&:to_s)

        raise Invalid, "Choose at least one person for this plan" if user_ids.empty?
        raise Invalid, "Board members changed; choose people again" if (user_ids - board_user_ids).any?

        request = BuildRequest.new(board: board, excluded_user_ids: board_user_ids - user_ids).call
        raise Invalid, "No eligible cards to plan" if request.candidate_work_units.empty?

        result = Solve.new(request: request).call
        raise Invalid, "No feasible plan was found" unless result.feasible?

        issue(board: board, request: request, result: result, user: user, planned_at: planned_at)
      end

      def current_for(board)
        proposal = where(board: board).recent_first.first
        proposal if proposal&.current?
      end

      def issue(board:, request:, result:, user: Current.user, planned_at: board.updated_at)
        assignments = result.proposed_assignments

        unless result.feasible? && assignments.map { |assignment| assignment.fetch(:card_id) }.sort == request.candidate_card_ids.sort &&
            assignments.all? { |assignment| request.users_by_id.key?(assignment.fetch(:assignee_id)) }
          raise Invalid, "The planner returned an incomplete proposal"
        end

        board.with_lock do
          # The plan was derived from the board as of planned_at. If anything
          # touched the board while the solver ran, the snapshot is gone.
          if board.updated_at.iso8601(6) != planned_at.iso8601(6)
            raise Invalid, "Board changed while planning; try again"
          end

          discard_proposals_for(board)
          # Create through the association: discard's delete_all leaves the
          # in-memory collection loaded, and dependent: :destroy trusts it.
          proposal = board.work_plan_proposals.create!(creator: user, board_updated_at: board.updated_at,
            excluded_user_ids: board.users.active.ids.map(&:to_s) - request.users.map(&:id))
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
