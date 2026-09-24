require "test_helper"
require "ostruct"

class Boards::WorkPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "admin can preview proposed work plan" do
    board = boards(:writebook)
    card = create_card_for(board:, title: "Plan this card")

    Board::WorkPlan::Solve.any_instance.stubs(:call).returns(
      OpenStruct.new(
        status: "feasible",
        score: "0hard/0medium/0soft",
        elapsed_ms: 4,
        proposed_assignments: [ { card_id: card.id.to_s, assignee_id: users(:kevin).id.to_s } ]
      )
    )

    get preview_board_work_plan_path(board)

    assert_response :success
    assert_select "p", "Solver score: 0hard/0medium/0soft"
    assert_select "input[name='plan[proposed_assignments][][card_id]'][value='#{card.id}']"
    assert_select "input[name='plan[proposed_assignments][][assignee_id]'][value='#{users(:kevin).id}']"
  end

  test "admin can preview proposed work plan end to end with the real solver" do
    board = create_board_for_tests
    card = create_card_for(board:, title: "Real solver preview card")

    get preview_board_work_plan_path(board)

    assert_response :success
    assert_select "p.txt-negative", count: 0
    assert_select "p", /Solver score:/
    assert_select "input[name='plan[proposed_assignments][][card_id]'][value='#{card.id}']"
    assert_select "input[name='plan[proposed_assignments][][assignee_id]'][value='#{users(:kevin).id}']"
  end

  test "admin sees an error when planner is infeasible" do
    board = boards(:writebook)
    Board::WorkPlan::Solve.any_instance.stubs(:call).returns(
      OpenStruct.new(
        status: "infeasible",
        score: "0hard/0medium/0soft",
        elapsed_ms: 0,
        proposed_assignments: []
      )
    )

    get preview_board_work_plan_path(board)

    assert_response :unprocessable_entity
    assert_select "p.txt-negative", "No feasible plan was found"
  end

  test "admin can apply a valid plan" do
    board = boards(:writebook)
    card = create_card_for(board:, title: "Apply this card")

    post apply_board_work_plan_path(board), params: {
      plan: {
        based_on_board_updated_at: board.updated_at.iso8601(6),
        proposed_assignments: [ { card_id: card.id.to_s, assignee_id: users(:kevin).id.to_s } ]
      }
    }

    assert_redirected_to board
    assert card.reload.assigned_to?(users(:kevin))
  end

  test "apply fails when plan is stale" do
    board = boards(:writebook)
    card = create_card_for(board:, title: "Stale plan card")
    board.reload

    post apply_board_work_plan_path(board), params: {
      plan: {
        based_on_board_updated_at: 1.second.ago.iso8601(6),
        proposed_assignments: [ { card_id: card.id.to_s, assignee_id: users(:kevin).id.to_s } ]
      }
    }

    assert_response :unprocessable_entity
    assert_select "p.txt-negative", "Board changed since plan was created"
    assert_not card.reload.assigned_to?(users(:kevin))
  end

  test "non-admin cannot preview or apply" do
    board = boards(:writebook)
    logout_and_sign_in_as :jz

    get preview_board_work_plan_path(board)
    assert_response :forbidden

    post apply_board_work_plan_path(board), params: {
      plan: {
        based_on_board_updated_at: board.updated_at.iso8601(6),
        proposed_assignments: []
      }
    }
    assert_response :forbidden
  end

  test "preview reports when no users or candidates exist" do
    board = create_board_for_tests
    request = Board::WorkPlan::BuildRequest::Request.new(
      board_id: board.id.to_s,
      time_limit_seconds: 30,
      users: [],
      work_units: [],
      candidate_work_units: [],
      pinned_work_units: []
    )

    Board::WorkPlan::BuildRequest.any_instance.stubs(:call).returns(request)

    get preview_board_work_plan_path(board)

    assert_response :unprocessable_entity
    assert_select "p.txt-negative", "No active board users available"
  end

  test "apply reports when assignee is no longer available" do
    board = boards(:writebook)
    card = create_card_for(board:, title: "No longer available assignee")

    post apply_board_work_plan_path(board), params: {
      plan: {
        based_on_board_updated_at: board.updated_at.iso8601(6),
        proposed_assignments: [ { card_id: card.id.to_s, assignee_id: users(:jason).id.to_s } ]
      }
    }

    assert_response :unprocessable_entity
    assert_select "p.txt-negative", "Assignee is no longer available"
  end

  private
    def create_card_for(board:, title:, **attributes)
      with_current_user(:kevin) do
        board.cards.create!(
          creator: users(:kevin),
          account: accounts("37s"),
          board: board,
          column: columns(:writebook_triage),
          status: :published,
          title: title,
          **attributes
        )
      end
    end

    def create_board_for_tests
      with_current_user(:kevin) do
        Board.create!(
          name: "No planning data",
          creator: users(:kevin),
          all_access: false,
          account: accounts("37s")
        )
      end
    end
end
