require "test_helper"

class Boards::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "show returns success for board member" do
    get board_report_path(@board)
    assert_response :success
  end

  test "show is accessible to board members" do
    logout_and_sign_in_as :jz
    get board_report_path(@board)
    assert_response :success
  end

  test "show requires board access" do
    logout_and_sign_in_as :david
    board = boards(:private)

    get board_report_path(board)
    assert_response :not_found
  end

  test "show renders a table row for each board card" do
    get board_report_path(@board)
    assert_select "table.reports-table tbody tr", count: @board.cards.count
  end

  test "show page is linked from board header" do
    get board_path(@board)
    assert_select "a[href='#{board_report_path(@board)}']"
  end
end
