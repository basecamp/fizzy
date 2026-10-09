require "test_helper"
require "tempfile"

class Board::WorkPlan::SolveTest < ActiveSupport::TestCase
  test "solve parses valid solver output" do
    script = Tempfile.new([ "solverforge-board-planner", ".sh" ])
    script.write <<~SH
      #!/usr/bin/env sh
      cat <<'JSON'
      {
        "status": "feasible",
        "score": "0hard/0medium/0soft",
        "elapsed_ms": 10,
        "proposed_assignments": [
          { "card_id": "card-1", "assignee_id": "user-1" },
          { "card_id": "card-2", "assignee_id": "user-2" }
        ]
      }
      JSON
    SH
    script.close
    FileUtils.chmod("+x", script.path)

    result = Board::WorkPlan::Solve.new(
      request: { time_limit_seconds: 1, users: [], work_units: [] },
      planner_binary_path: script.path
    ).call

    assert_equal true, result.feasible?
    assert_equal 10, result.elapsed_ms
    assert_equal 2, result.proposed_assignments.size
  ensure
    script.unlink
  end

  test "solve raises parse error on invalid output" do
    script = Tempfile.new([ "solverforge-board-planner", ".sh" ])
    script.write <<~SH
      #!/usr/bin/env sh
      echo not-json
    SH
    script.close
    FileUtils.chmod("+x", script.path)

    assert_raises Board::WorkPlan::Solve::ParseError do
      Board::WorkPlan::Solve.new(
        request: { users: [], work_units: [] },
        planner_binary_path: script.path
      ).call
    end
  ensure
    script.unlink
  end

  test "solve raises execution error when binary is missing" do
    assert_raises Board::WorkPlan::Solve::ExecutionError, "Solver binary is unavailable" do
      Board::WorkPlan::Solve.new(request: { users: [], work_units: [] }, planner_binary_path: "/definitely-missing-planner").call
    end
  end
end
