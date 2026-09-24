module Board::WorkPlan
  class Apply
    class Error < StandardError; end
    class StalePlanError < Error; end
    class InvalidPlanError < Error; end

    Result = Struct.new(:applied_assignments, :updated_board, :based_on_board_updated_at, keyword_init: true)

    def initialize(board:, plan:)
      @board = board
      @plan = plan || {}
    end

    def call
      parsed_board_updated_at = parse_board_timestamp
      ensure_board_unchanged!(parsed_board_updated_at)

      ensure_unique_cards!
      proposals = normalized_proposals

      proposals.each do |proposal|
        validate_proposal!(proposal)
      end

      applied = []
      ActiveRecord::Base.transaction do
        proposals.each do |proposal|
          card = proposal.fetch(:card)
          assignee = proposal.fetch(:assignee)

          assigned = card.assign_to(assignee, assigner: Current.user)
          raise StalePlanError, "Failed to apply assignment" unless assigned

          applied << proposal.fetch(:card)
        end
      end

      Result.new(applied_assignments: applied, updated_board: board, based_on_board_updated_at: parsed_board_updated_at)
    end

    private
      attr_reader :board, :plan

      def parse_board_timestamp
        raw_timestamp = plan.fetch("based_on_board_updated_at") { plan.fetch(:based_on_board_updated_at) { raise InvalidPlanError, "Missing board timestamp" } }

        Time.zone.parse(raw_timestamp.to_s) or raise InvalidPlanError, "Invalid board timestamp"
      rescue ArgumentError
        raise InvalidPlanError, "Invalid board timestamp"
      end

      def ensure_board_unchanged!(parsed_board_updated_at)
        raise StalePlanError, "Board changed since plan was created" unless board.updated_at.iso8601(6) == parsed_board_updated_at.iso8601(6)
      end

      def normalized_proposals
        Array(proposed_assignments_param).map do |proposal|
          {
            card_id: proposal.fetch(:card_id, proposal.fetch("card_id", nil))&.to_s,
            assignee_id: proposal.fetch(:assignee_id, proposal.fetch("assignee_id", nil))&.to_s
          }
        end
      end

      def ensure_unique_cards!
        duplicates = normalized_proposals.group_by { |proposal| proposal[:card_id].to_s }.select { |_, entries| entries.size > 1 }
        raise InvalidPlanError, "Duplicate card assignments in plan" if duplicates.any?
      end

      def proposed_assignments_param
        plan[:proposed_assignments] || plan["proposed_assignments"] || []
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
