require "test_helper"

class Boards::WorkPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = with_current_user(:kevin) { Board.create!(name: "Planning", all_access: false) }
    column = @board.columns.create!(name: "Doing")
    @card = with_current_user(:kevin) { @board.cards.create!(title: "Work to plan", column: column, status: :published) }
    @board.update!(work_planning_time_limit_in_seconds: 5)
  end

  test "the page loads instantly and plans within its frame" do
    get board_work_plan_path(@board)

    assert_response :success
    assert_select "fieldset legend", /Who should get work/
    assert_select "form[action=?]", board_work_plan_proposal_path(@board)
    assert_select "input[type=submit][value='Review plan']"
    assert_select "input[name='user_ids[]'][value=?][checked]", users(:kevin).id
    assert_select "turbo-frame##{dom_id(@board, :work_plan)}[src]", count: 0
    assert_select ".work-plan__summary", count: 0
    assert_not @card.reload.assigned?
  end

  test "preview uses the real solver without assigning a card until approved" do
    review_plan

    assert_response :success
    assert_select ".work-plan__summary", /1 card for 1 person/
    assert_select ".work-plan__card", text: /Work to plan/
    assert_select "input[name=proposal_id]", count: 1
    assert_not @card.reload.assigned?

    proposal_id = css_select("input[name=proposal_id]").first["value"]
    post board_work_plan_approval_path(@board), params: { proposal_id: proposal_id }

    assert_redirected_to @board
    assert @card.reload.assigned_to?(users(:kevin))
  end

  test "a second preview reuses the plan instead of solving again" do
    review_plan
    proposal_id = css_select("input[name=proposal_id]").first["value"]

    get board_work_plan_path(@board), headers: turbo_frame_headers

    assert_response :success
    assert_equal proposal_id, css_select("input[name=proposal_id]").first["value"]
    assert_equal 1, Board::WorkPlan::Proposal.where(board: @board).count
  end

  test "an admin can leave out a board member without changing board access" do
    @board.accesses.create!(user: users(:david))
    @board.reload

    review_plan(user_ids: [ users(:kevin).id ])

    assert_response :success
    proposal = Board::WorkPlan::Proposal.find(css_select("input[name=proposal_id]").first["value"])
    assert_equal [ users(:david).id ], proposal.excluded_user_ids
    assert_equal [ users(:kevin).id ], proposal.assignments.pluck(:assignee_id).uniq
    assert @board.accessible_to?(users(:david))

    get board_work_plan_path(@board)

    assert_response :success
    assert_select "input[name='user_ids[]'][value=?][checked]", users(:kevin).id
    assert_select "input[name='user_ids[]'][value=?][checked]", users(:david).id, count: 0
    assert_select "turbo-frame[src=?]", board_work_plan_path(@board)
  end

  test "only board members can be excluded from a plan" do
    review_plan(user_ids: [ users(:kevin).id, users(:jz).id ])

    assert_response :success
    assert_select ".work-plan__empty", /Board members changed/
    assert_equal 0, Board::WorkPlan::Proposal.where(board: @board).count
    assert_not @card.reload.assigned?
  end

  test "a plan needs at least one eligible person" do
    review_plan(user_ids: [ "" ])

    assert_response :success
    assert_select ".work-plan__empty", /Choose at least one person/
    assert_equal 0, Board::WorkPlan::Proposal.where(board: @board).count
  end

  test "each page shows only its cards while approval assigns the whole proposal" do
    cards = [ @card ] + 15.times.map do |number|
      with_current_user(:kevin) do
        @board.cards.create!(title: "Planned card #{number}", column: @card.column, status: :published)
      end
    end
    request = Board::WorkPlan::BuildRequest.new(board: @board).call
    result = Board::WorkPlan::Solve::Result.new(
      status: "feasible", score: "0hard/0medium/0soft", elapsed_ms: 1,
      proposed_assignments: cards.map { |card| { card_id: card.id, assignee_id: users(:kevin).id } }
    )
    proposal = Board::WorkPlan::Proposal.issue(board: @board, request: request, result: result, user: users(:kevin))

    get board_work_plan_path(@board), headers: turbo_frame_headers

    assert_response :success
    assert_select ".work-plan__summary", /16 cards for 1 person/
    assert_select ".work-plan__card", count: 15
    assert_select ".work-plan__person-heading", /16 cards/
    assert_select "a[href=?]", board_work_plan_path(@board, page: 2), count: 1
    first_page = css_select(".work-plan__title").map(&:text)

    get board_work_plan_path(@board, page: 2), headers: { "Turbo-Frame" => "work_plan-pagination-contents-2" }

    assert_response :success
    assert_select "turbo-frame#work_plan-pagination-contents-2 .work-plan__card", count: 1
    assert_select ".work-plan__person-heading", /continued.*16 cards/m
    assert_equal cards.map(&:title).sort, (first_page + css_select(".work-plan__title").map(&:text)).sort

    post board_work_plan_approval_path(@board), params: { proposal_id: proposal.id }

    assert_redirected_to @board
    assert_equal 0, @board.cards.triaged.unassigned.count
    assert cards.all? { |card| card.reload.assigned_to?(users(:kevin)) }
  end

  test "approval of a stale proposal writes nothing" do
    review_plan
    proposal_id = css_select("input[name=proposal_id]").first["value"]
    @card.update!(title: "Changed since planning")

    post board_work_plan_approval_path(@board), params: { proposal_id: proposal_id }

    assert_redirected_to @board
    assert_not @card.reload.assigned?
  end

  test "another user cannot approve a proposal for a board they cannot access" do
    review_plan
    proposal_id = css_select("input[name=proposal_id]").first["value"]
    logout_and_sign_in_as :jz

    post board_work_plan_approval_path(@board), params: { proposal_id: proposal_id }

    assert_response :not_found
    assert_not @card.reload.assigned?
  end

  test "non-admin cannot view or approve a proposal" do
    board = boards(:writebook)
    logout_and_sign_in_as :jz

    get board_work_plan_path(board)
    assert_response :forbidden

    post board_work_plan_proposal_path(board), params: { user_ids: [ users(:jz).id ] }
    assert_response :forbidden

    post board_work_plan_approval_path(board), params: { proposal_id: "whatever" }
    assert_response :forbidden
  end

  private
    def review_plan(user_ids: [ users(:kevin).id ])
      post board_work_plan_proposal_path(@board), params: { user_ids: user_ids }, headers: turbo_frame_headers
      assert_redirected_to board_work_plan_path(@board)
      get board_work_plan_path(@board), headers: turbo_frame_headers
    end

    def turbo_frame_headers
      { "Turbo-Frame" => dom_id(@board, :work_plan) }
    end
end
