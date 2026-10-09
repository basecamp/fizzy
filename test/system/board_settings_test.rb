require "application_system_test_case"

class BoardSettingsTest < ApplicationSystemTestCase
  test "board settings shows access members and planning time in seconds" do
    board = boards(:writebook)

    sign_in_as(users(:kevin))
    visit edit_board_path(board)

    assert_text "Who can access this board?"
    board.account.users.active.each do |user|
      assert_text user.name
    end

    assert_text "Planning time"
    assert_selector ".knob__label", text: "SECONDS"
  end
end
