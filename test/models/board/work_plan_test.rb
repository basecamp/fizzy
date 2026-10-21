require "test_helper"

class Board::WorkPlanTest < ActiveSupport::TestCase
  test "planning time limit defaults to 30 seconds" do
    board = with_current_user(:kevin) do
      Board.create!(name: "Planner defaults", creator: users(:kevin), all_access: true)
    end

    assert_equal 30, board.work_planning_time_limit_in_seconds
  end

  test "planning time limit only accepts configured presets" do
    board = boards(:writebook)

    assert_raises ActiveRecord::RecordInvalid do
      board.update!(work_planning_time_limit_in_seconds: 15)
    end
  end

  test "destroying a board removes its proposals and their assignments" do
    board = with_current_user(:kevin) { Board.create!(name: "Planner cleanup", all_access: false) }
    column = board.columns.create!(name: "Doing")
    card = with_current_user(:kevin) { board.cards.create!(title: "Doomed work", column: column, status: :published) }
    request = Board::WorkPlan::BuildRequest.new(board: board).call
    result = Board::WorkPlan::Solve::Result.new(
      status: "feasible", score: "0hard/0medium/0soft", elapsed_ms: 1,
      proposed_assignments: [ { card_id: card.id, assignee_id: users(:kevin).id } ]
    )
    proposal = Board::WorkPlan::Proposal.issue(board: board, request: request, result: result, user: users(:kevin))

    board.destroy!

    assert_not Board::WorkPlan::Proposal.exists?(proposal.id)
    assert_empty Board::WorkPlan::Proposal::Assignment.where(proposal_id: proposal.id)
  end
end
