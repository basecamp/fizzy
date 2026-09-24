require "digest"

module Board::WorkPlan
  class Proposal
    class Invalid < StandardError; end
    class Stale < StandardError; end

    def self.issue(board:, request:, result:, user: Current.user)
      assignments = result.proposed_assignments
      candidate_ids = request.candidate_card_ids

      unless result.feasible? && assignments.map { |assignment| assignment.fetch(:card_id) }.sort == candidate_ids.sort &&
          assignments.all? { |assignment| request.users_by_id.key?(assignment.fetch(:assignee_id)) }
        raise Invalid, "The planner returned an incomplete proposal"
      end

      verifier.generate({
        board_id: board.id,
        user_id: user.id,
        board_updated_at: board.updated_at.iso8601(6),
        request_digest: digest(request),
        proposed_assignments: assignments
      }, expires_in: 10.minutes)
    end

    def self.verify(token, board:, user: Current.user)
      payload = verifier.verify(token).deep_symbolize_keys

      unless payload.fetch(:board_id) == board.id && payload.fetch(:user_id) == user.id
        raise Invalid, "This proposal belongs to another board or user"
      end

      request = BuildRequest.new(board: board).call
      unless payload.fetch(:board_updated_at) == board.updated_at.iso8601(6) &&
          payload.fetch(:request_digest) == digest(request)
        raise Stale, "Board changed since plan was created"
      end

      payload.fetch(:proposed_assignments)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, TypeError
      raise Invalid, "Proposal is invalid or has expired; plan again"
    end

    def self.digest(request)
      payload = request.to_h
      payload[:users].sort_by! { |user| user.fetch(:id) }
      payload[:work_units].sort_by! { |unit| unit.fetch(:id) }
      Digest::SHA256.hexdigest(JSON.generate(payload))
    end

    def self.verifier
      Rails.application.message_verifier(:board_work_plans)
    end
    private_class_method :digest, :verifier
  end
end
