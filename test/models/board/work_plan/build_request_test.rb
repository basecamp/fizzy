require "test_helper"

class Board::WorkPlan::BuildRequestTest < ActiveSupport::TestCase
  setup do
    @board = boards(:writebook)
    @triage_column = columns(:writebook_triage)
  end

  test "build_request includes triaged unassigned candidates" do
    candidate = create_card(
      title: "Plan me",
      due_on: Time.zone.today
    )
    ineligible_assigned = create_card(
      title: "Already assigned",
      due_on: Time.zone.tomorrow
    )
    ineligible_assigned.assign_to(users(:kevin), assigner: users(:david))

    ineligible_draft = create_card(title: "Not triaged", due_on: Time.zone.today, status: :drafted, column: nil)

    result = Board::WorkPlan::BuildRequest.new(board: @board).call

    assert_includes result.candidate_card_ids, candidate.id.to_s
    assert_not_includes result.candidate_card_ids, ineligible_assigned.id.to_s
    assert_not_includes result.candidate_card_ids, ineligible_draft.id.to_s
  end

  test "build_request computes urgency weights with configured bonuses" do
    travel_to Time.zone.local(2026, 3, 26, 10, 0, 0) do
      overdue = create_card(
        title: "Overdue",
        due_on: (Time.zone.today - 1.day),
      )
      due_today = create_card(
        title: "Due today",
        due_on: Time.zone.today
      )
      due_in_few_days = create_card(
        title: "Due in 2 days",
        due_on: Time.zone.today + 2.days
      )

      due_in_week = create_card(
        title: "Due in 6 days",
        due_on: Time.zone.today + 6.days
      )
      without_due = create_card(
        title: "No due date"
      )

      due_today.gild
      due_in_few_days.update!(updated_at: 15.days.ago)
      Card::ActivitySpike.create!(
        account: accounts("37s"),
        card: due_in_few_days,
        created_at: 15.days.ago,
        updated_at: 15.days.ago
      )
      due_in_few_days.reload
      due_in_few_days.update_column(:updated_at, 15.days.ago)

      result = Board::WorkPlan::BuildRequest.new(board: @board).call

      assert_equal 8, result.candidate_by_card_id(overdue.id.to_s).urgency_weight
      assert_equal 10, result.candidate_by_card_id(due_today.id.to_s).urgency_weight
      assert_equal 6, result.candidate_by_card_id(due_in_few_days.id.to_s).urgency_weight
      assert_equal 3, result.candidate_by_card_id(due_in_week.id.to_s).urgency_weight
      assert_equal 1, result.candidate_by_card_id(without_due.id.to_s).urgency_weight
    end
  end

  test "build_request includes pinned workload for active board assignees only" do
    pinned_card = create_card(title: "Pinned work", due_on: Time.zone.today)
    pinned_card.assign_to(users(:kevin), assigner: users(:david))
    pinned_card.assign_to(users(:jason), assigner: users(:david))

    result = Board::WorkPlan::BuildRequest.new(board: @board).call

    kevin_pinned = result.pinned_work_units_for(users(:kevin).id)
    jason_pinned = result.pinned_work_units_for(users(:jason).id)

    assert_operator kevin_pinned.size, :>, 0
    assert_empty jason_pinned
    assert kevin_pinned.any? { |unit| unit.card_id == pinned_card.id.to_s }
  end

  test "build_request serializes planner booleans as false instead of null" do
    candidate = create_card(title: "Boolean-safe planner payload")

    result = Board::WorkPlan::BuildRequest.new(board: @board).call
    payload = JSON.parse(result.to_json)
    work_unit = payload.fetch("work_units").find { |unit| unit["card_id"] == candidate.id.to_s }

    assert_equal false, work_unit["golden"]
    assert_equal false, work_unit["stalled"]
  end

  private
    def create_card(**attributes)
      with_current_user(:kevin) do
        column = attributes.key?(:column) ? attributes.delete(:column) : @triage_column
        @board.cards.create!(
          creator: users(:kevin),
          account: accounts("37s"),
          board: @board,
          column: column,
          status: attributes.delete(:status) || :published,
          **attributes
        )
      end
    end
end
