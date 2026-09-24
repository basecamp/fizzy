require "test_helper"

class Board::WorkPlan::ApplyTest < ActiveSupport::TestCase
  setup do
    @board = with_current_user(:kevin) { Board.create!(name: "Planning", all_access: false) }
    @column = @board.columns.create!(name: "Doing")
    @card = with_current_user(:kevin) do
      @board.cards.create!(title: "Unassigned work", column: @column, status: :published)
    end
  end

  test "only the current proposal persists the assignment, and only once" do
    proposal = build_proposal

    assert_not @card.reload.assigned?
    result = with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, proposal: proposal).call }

    assert_equal [ @card ], result.applied_assignments
    assert @card.reload.assigned_to?(users(:kevin))

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, proposal: proposal).call }
    end
    assert_equal 1, @card.assignments.count
  end

  test "a board change makes a proposal stale before any write" do
    proposal = build_proposal
    @card.update!(title: "Changed after preview")

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, proposal: proposal).call }
    end
    assert_not @card.reload.assigned?
  end

  test "a changed board member makes a proposal stale" do
    proposal = build_proposal
    @board.accesses.find_by!(user: users(:kevin)).destroy!

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: @board, proposal: proposal).call }
    end
    assert_not @card.reload.assigned?
  end

  test "a proposal cannot be applied to another board" do
    proposal = build_proposal
    another_board = with_current_user(:kevin) { Board.create!(name: "Elsewhere", all_access: false) }

    assert_raises(Board::WorkPlan::Apply::StalePlanError) do
      with_current_user(:kevin) { Board::WorkPlan::Apply.new(board: another_board, proposal: proposal).call }
    end
    assert_not @card.reload.assigned?
  end

  test "a duplicate card assignment is rejected" do
    request = Board::WorkPlan::BuildRequest.new(board: @board).call
    result = Board::WorkPlan::Solve::Result.new(
      status: "feasible", score: "0hard/0medium/0soft", elapsed_ms: 1,
      proposed_assignments: [ { card_id: @card.id, assignee_id: users(:kevin).id } ] * 2
    )

    assert_raises(Board::WorkPlan::Proposal::Invalid) do
      Board::WorkPlan::Proposal.issue(board: @board, request: request, result: result, user: users(:kevin))
    end
    assert_not @card.reload.assigned?
  end

  test "an excluded board member cannot appear in the solver proposal" do
    @board.accesses.create!(user: users(:david))
    request = Board::WorkPlan::BuildRequest.new(board: @board, excluded_user_ids: [ users(:david).id ]).call
    result = Board::WorkPlan::Solve::Result.new(
      status: "feasible", score: "0hard/0medium/0soft", elapsed_ms: 1,
      proposed_assignments: [ { card_id: @card.id, assignee_id: users(:david).id } ]
    )

    assert_raises(Board::WorkPlan::Proposal::Invalid) do
      Board::WorkPlan::Proposal.issue(board: @board, request: request, result: result, user: users(:kevin))
    end
    assert_not @card.reload.assigned?
  end

  test "issuing a new proposal discards the board's previous one" do
    build_proposal
    build_proposal

    assert_equal 1, Board::WorkPlan::Proposal.where(board: @board).count
  end

  private
    def build_proposal
      request = Board::WorkPlan::BuildRequest.new(board: @board).call
      result = Board::WorkPlan::Solve::Result.new(
        status: "feasible", score: "0hard/0medium/0soft", elapsed_ms: 1,
        proposed_assignments: [ { card_id: @card.id, assignee_id: users(:kevin).id } ]
      )
      Board::WorkPlan::Proposal.issue(board: @board, request: request, result: result, user: users(:kevin))
    end
end
