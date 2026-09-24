require "test_helper"

class Board::WorkPlan::ApplyTest < ActiveSupport::TestCase
  setup do
    @board = boards(:writebook)
    @triage_column = columns(:writebook_triage)
  end

  test "apply assigns each proposed card to requested assignee" do
    card = create_card(title: "Staging card", due_on: Time.zone.today)

    plan = {
      based_on_board_updated_at: @board.updated_at.iso8601(6),
      proposed_assignments: [
        { card_id: card.id, assignee_id: users(:jz).id }
      ]
    }

    result = Board::WorkPlan::Apply.new(board: @board, plan: plan).call

    assert_equal [ card ], result.applied_assignments
    assert_equal @board, result.updated_board
    assert card.reload.assigned_to?(users(:jz))
  end

  test "apply fails when board changed since preview" do
    card = create_card(title: "Stale board card", due_on: Time.zone.today)

    plan = {
      based_on_board_updated_at: (@board.updated_at - 1.minute).iso8601(6),
      proposed_assignments: [
        { card_id: card.id, assignee_id: users(:jz).id }
      ]
    }

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      Board::WorkPlan::Apply.new(board: @board, plan: plan).call
    end
    assert_not card.reload.assigned_to?(users(:jz))
  end

  test "apply requires cards to still be eligible" do
    card = create_card(title: "Assigned card")
    card.assign_to(users(:david), assigner: users(:kevin))

    plan = {
      based_on_board_updated_at: @board.updated_at.iso8601(6),
      proposed_assignments: [
        { card_id: card.id, assignee_id: users(:jz).id }
      ]
    }

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      Board::WorkPlan::Apply.new(board: @board, plan: plan).call
    end
  end

  test "apply requires assignee to still be an active board user" do
    card = create_card(title: "Assignee not in board")

    plan = {
      based_on_board_updated_at: @board.updated_at.iso8601(6),
      proposed_assignments: [
        { card_id: card.id, assignee_id: users(:jason).id }
      ]
    }

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      Board::WorkPlan::Apply.new(board: @board, plan: plan).call
    end
  end

  test "apply rejects duplicate card assignments" do
    card = create_card(title: "Duplicate card")

    plan = {
      based_on_board_updated_at: @board.updated_at.iso8601(6),
      proposed_assignments: [
        { card_id: card.id, assignee_id: users(:jz).id },
        { card_id: card.id, assignee_id: users(:david).id }
      ]
    }

    assert_raises(Board::WorkPlan::Apply::InvalidPlanError) do
      Board::WorkPlan::Apply.new(board: @board, plan: plan).call
    end
  end

  private
    def create_card(title:, **attributes)
      with_current_user(:kevin) do
        @board.cards.create!(
          creator: users(:kevin),
          account: accounts("37s"),
          board: @board,
          column: @triage_column,
          status: :published,
          title: title,
          **attributes
        )
      end
    end
end
