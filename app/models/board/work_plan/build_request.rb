module Board::WorkPlan
  require_relative "domain"

  class BuildRequest
    Request = Struct.new(:board_id, :time_limit_seconds, :users, :work_units, :candidate_work_units, :pinned_work_units, keyword_init: true) do
      def to_h
        {
          board_id: board_id,
          time_limit_seconds: time_limit_seconds,
          users: users.map(&:to_h),
          work_units: work_units.map(&:to_h)
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def users_by_id
        @users_by_id ||= users.index_by(&:id)
      end

      def pinned_work_units_for(assignee_id)
        pinned_work_units.select { |unit| unit.assignee_id == assignee_id.to_s }
      end

      def candidate_card_ids
        candidate_work_units.map(&:card_id)
      end

      def candidate_by_card_id(card_id)
        candidate_work_units.find { |work_unit| work_unit.card_id == card_id.to_s }
      end
    end

    def initialize(board:)
      @board = board
    end

    def call
      Request.new(
        board_id: board.id.to_s,
        time_limit_seconds: board.work_planning_time_limit_in_seconds,
        users: users,
        work_units: work_units,
        candidate_work_units: candidate_work_units,
        pinned_work_units: pinned_work_units
      )
    end

    private
      attr_reader :board

      def users
        @users ||= board.users.active.alphabetically.map do |user|
          PlannerUser.new(id: user.id.to_s, name: user.name)
        end
      end

      def user_index
        @user_index ||= users.each_with_index.each_with_object({}) do |(user, idx), memo|
          memo[user.id] = idx
        end
      end

      def work_units
        @work_units ||= begin
          work_units = pinned_work_units + candidate_work_units
          work_units.sort_by! { |unit| unit.pinned? ? 0 : 1 }
          work_units
        end
      end

      def pinned_work_units
        @pinned_work_units ||= board.cards.active.includes(:goldness, :activity_spike, assignments: :assignee).flat_map do |card|
          card.assignments.map do |assignment|
            assignee_id = assignment.assignee_id.to_s
            next if user_index[assignee_id].nil?

            WorkUnit.new(
              id: "pinned:#{assignment.id}",
              card_id: card.id.to_s,
              card_number: card.number,
              title: card.title,
              due_on: card.due_on&.iso8601,
              golden: !!card.golden?,
              stalled: !!card.stalled?,
              urgency_weight: urgency_weight_for(card),
              assignee_id: assignee_id,
              assignee_idx: user_index[assignee_id],
              pinned: true
            )
          end
        end.compact
      end

      def candidate_work_units
        @candidate_work_units ||= board.cards.triaged.unassigned.includes(:goldness, :activity_spike).map do |card|
          WorkUnit.new(
            id: "card:#{card.id}",
            card_id: card.id.to_s,
            card_number: card.number,
            title: card.title,
            due_on: card.due_on&.iso8601,
            golden: !!card.golden?,
            stalled: !!card.stalled?,
            urgency_weight: urgency_weight_for(card),
            assignee_id: nil,
            assignee_idx: nil,
            pinned: false
          )
        end
      end

      def urgency_weight_for(card)
        base = urgency_for_due_date(card.due_on)
        base + (card.golden? ? 2 : 0) + (card.stalled? ? 1 : 0)
      end

      def urgency_for_due_date(due_on)
        return 1 unless due_on

        delta = (due_on - Time.zone.today).to_i

        if delta <= 0
          8
        elsif delta <= 3
          5
        elsif delta <= 7
          3
        else
          1
        end
      end
  end
end
