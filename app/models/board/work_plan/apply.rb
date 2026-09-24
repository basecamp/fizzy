module Board::WorkPlan
  class Apply
    class Error < StandardError; end
    class StalePlanError < Error; end
    class InvalidPlanError < Error; end

    Result = Struct.new(:applied_assignments, :updated_board, keyword_init: true)

    def initialize(board:, token:)
      @board = board
      @token = token
    end

    def call
      board.with_lock do
        assignments = Proposal.verify(token, board: board)
        proposals = normalized_proposals(assignments)
        ensure_unique_cards!(proposals)
        proposals.each { |proposal| validate_proposal!(proposal) }

        applied = []
        proposals.each do |proposal|
          card = proposal.fetch(:card)
          assignee = proposal.fetch(:assignee)

          assigned = card.assign_to(assignee, assigner: Current.user)
          raise StalePlanError, "Failed to apply assignment" unless assigned

          applied << proposal.fetch(:card)
        end

        Result.new(applied_assignments: applied, updated_board: board)
      end
    rescue Proposal::Stale => error
      raise StalePlanError, error.message
    rescue Proposal::Invalid => error
      raise InvalidPlanError, error.message
    end

    private
      attr_reader :board, :token

      def normalized_proposals(assignments)
        assignments.map do |proposal|
          {
            card_id: proposal.fetch(:card_id).to_s,
            assignee_id: proposal.fetch(:assignee_id).to_s
          }
        end
      end

      def ensure_unique_cards!(proposals)
        duplicates = proposals.group_by { |proposal| proposal[:card_id] }.select { |_, entries| entries.size > 1 }
        raise InvalidPlanError, "Duplicate card assignments in plan" if duplicates.any?
      end

      def validate_proposal!(proposal)
        card_id = proposal[:card_id].to_s
        assignee_id = proposal[:assignee_id].to_s

        raise InvalidPlanError, "Incomplete proposal data" if card_id.blank? || assignee_id.blank?

        proposal[:card] = board.cards.triaged.unassigned.find_by(id: card_id) ||
          raise(StalePlanError, "Card is no longer eligible")
        proposal[:assignee] = board.users.active.find_by(id: assignee_id) ||
          raise(StalePlanError, "Assignee is no longer available")
      end
  end
end
