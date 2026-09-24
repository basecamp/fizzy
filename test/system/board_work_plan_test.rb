require "application_system_test_case"

class BoardWorkPlanTest < ApplicationSystemTestCase
  setup do
    @board = boards(:writebook)
    @board.update!(work_planning_time_limit_in_seconds: 5)

    @card = with_current_user(:kevin) do
      @board.cards.create!(title: "Plan this card", column: columns(:writebook_triage), status: :published)
    end
  end

  test "an admin previews the plan and approves it" do
    sign_in_as users(:kevin)
    visit board_path(@board)

    click_on "Assign work"

    # The solver runs while the frame loads, so wait past the default timeout.
    assert_selector ".work-plan__summary", wait: 15
    assert_selector ".work-plan__person-name"
    assert_text "Plan this card"

    click_on "Approve and assign"

    assert_text "Work plan applied"
    assert @card.reload.assigned?
  end
end
