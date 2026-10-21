require "test_helper"

class Board::WorkPlan::SolveSmokeTest < ActiveSupport::TestCase
  test "solve executes the compiled planner binary if available" do
    binary = Rails.root.join("vendor", "bin", "solverforge-board-planner")

    result = Board::WorkPlan::Solve.new(
      request: {
        board_id: "plan_smoke",
        time_limit_seconds: 1,
        users: [ { id: "user-a", name: "User A" } ],
        work_units: [
          {
            id: "card-1",
            card_id: "card-1",
            card_number: 1,
            title: "Smoke test card",
            due_on: nil,
            golden: false,
            stalled: false,
            urgency_weight: 1,
            assignee_id: nil,
            pinned: false
          }
        ],
        candidate_work_units: [
          {
            id: "card-1",
            card_id: "card-1",
            card_number: 1,
            title: "Smoke test card",
            due_on: nil,
            golden: false,
            stalled: false,
            urgency_weight: 1,
            assignee_id: nil,
            pinned: false
          }
          ],
        pinned_work_units: []
      },
      planner_binary_path: binary
    ).call

    assert result.feasible?
    assert_equal [ { card_id: "card-1", assignee_id: "user-a" } ], result.proposed_assignments
  end
end
