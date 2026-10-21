module Board::WorkPlan
  class Apply
    class Error < StandardError; end
    class StalePlanError < Error; end
    class InvalidPlanError < Error; end

    Result = Struct.new(:applied_assignments, :updated_board, keyword_init: true)

    def initialize(board:, proposal:)
      @board = board
      @proposal = proposal
    end

    def call
      board.with_lock do
        raise StalePlanError, "Board changed since plan was created" unless proposal.current?

        ensure_unique_cards!

        cards = board.cards.triaged.unassigned.where(id: proposal.assignments.select(:card_id)).index_by(&:id)
        assignees = board.users.active.index_by(&:id)

        applied = proposal.assignments.map do |assignment|
          card = cards.fetch(assignment.card_id) { raise StalePlanError, "Card is no longer eligible" }
          assignee = assignees.fetch(assignment.assignee_id) { raise StalePlanError, "Assignee is no longer available" }

          assigned = card.assign_to(assignee, assigner: Current.user)
          raise StalePlanError, "Failed to apply assignment" unless assigned

          card
        end

        Result.new(applied_assignments: applied, updated_board: board)
      end
    end

    private
      attr_reader :board, :proposal

      def ensure_unique_cards!
        duplicates = proposal.assignments.group_by(&:card_id).select { |_, entries| entries.size > 1 }
        raise InvalidPlanError, "Duplicate card assignments in plan" if duplicates.any?
      end
  end
end
