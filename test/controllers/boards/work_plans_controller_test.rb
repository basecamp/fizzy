require "test_helper"

class Boards::WorkPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = with_current_user(:kevin) { Board.create!(name: "Planning", all_access: false) }
    column = @board.columns.create!(name: "Doing")
    @card = with_current_user(:kevin) { @board.cards.create!(title: "Work to plan", column: column, status: :published) }
    @board.update!(work_planning_time_limit_in_seconds: 5)
  end

  test "preview uses the real solver without assigning a card until approved" do
    get board_work_plan_path(@board)

    assert_response :success
    assert_select ".work-plan__summary", /1 card for 1 person/
    assert_select ".work-plan__card", text: /Work to plan/
    assert_select "input[name=proposal_token]", count: 1
    assert_not @card.reload.assigned?

    token = css_select("input[name=proposal_token]").first["value"]
    post board_work_plan_approval_path(@board), params: { proposal_token: token }

    assert_redirected_to @board
    assert @card.reload.assigned_to?(users(:kevin))
  end

  test "approval of a stale proposal writes nothing" do
    get board_work_plan_path(@board)
    token = css_select("input[name=proposal_token]").first["value"]
    @card.update!(title: "Changed since planning")

    post board_work_plan_approval_path(@board), params: { proposal_token: token }

    assert_redirected_to @board
    assert_not @card.reload.assigned?
  end

  test "another user cannot approve a proposal for a board they cannot access" do
    get board_work_plan_path(@board)
    token = css_select("input[name=proposal_token]").first["value"]
    logout_and_sign_in_as :jz

    post board_work_plan_approval_path(@board), params: { proposal_token: token }

    assert_response :not_found
    assert_not @card.reload.assigned?
  end

  test "non-admin cannot view or approve a proposal" do
    board = boards(:writebook)
    logout_and_sign_in_as :jz

    get board_work_plan_path(board)
    assert_response :forbidden

    post board_work_plan_approval_path(board), params: { proposal_token: "invalid" }
    assert_response :forbidden
  end
end
