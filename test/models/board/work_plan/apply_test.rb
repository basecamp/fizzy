require "test_helper"

class Board::WorkPlan::ApplyTest < ActiveSupport::TestCase
  setup do
    @board = with_current_user(:kevin) { Board.create!(name: "Planning", all_access: false) }
    @column = @board.columns.create!(name: "Doing")
    @card = with_current_user(:kevin) do
      @board.cards.create!(title: "Unassigned work", column: @column, status: :published)
    end
  end

  test "only an approved, signed proposal persists the assignment" do
    token = proposal_token

    assert_not @card.reload.assigned?
    result = with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, token: token).call }

    assert_equal [ @card ], result.applied_assignments
    assert @card.reload.assigned_to?(users(:kevin))

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, token: token).call }
    end
    assert_equal 1, @card.assignments.count
  end

  test "a board change makes a proposal stale before any write" do
    token = proposal_token
    @card.update!(title: "Changed after preview")

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, token: token).call }
    end
    assert_not @card.reload.assigned?
  end

  test "a changed board member makes a proposal stale" do
    token = proposal_token
    @board.accesses.find_by!(user: users(:kevin)).destroy!

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, token: token).call }
    end
    assert_not @card.reload.assigned?
  end

  test "forged, cross-board and cross-user proposals cannot be applied" do
    token = proposal_token
    another_board = with_current_user(:kevin) { Board.create!(name: "Elsewhere", all_access: false) }

    assert_raises(Board::WorkPlan::Apply::InvalidPlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, token: token.reverse).call }
    end
    assert_raises(Board::WorkPlan::Apply::InvalidPlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: another_board, token: token).call }
    end
    assert_raises(Board::WorkPlan::Apply::InvalidPlanError) do
      with_current_user(:jz) { Board::WorkPlan::Apply.new(board: @board, token: token).call }
    end
    assert_not @card.reload.assigned?
  end

  private
    def proposal_token
      request = Board::WorkPlan::BuildRequest.new(board: @board).call
      result = Board::WorkPlan::Solve::Result.new(
        status: "feasible", score: "0hard/0medium/0soft", elapsed_ms: 1,
        proposed_assignments: [ { card_id: @card.id, assignee_id: users(:kevin).id } ]
      )
      Board::WorkPlan::Proposal.issue(board: @board, request: request, result: result, user: users(:kevin))
    end
end
