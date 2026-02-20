require "test_helper"

class BoardsHelperTest < ActionView::TestCase
  include BoardsHelper
  include ApplicationHelper
  fixtures :boards

  setup do
    @board = Board.find(
    ActiveRecord::FixtureSet.identify("writebook", :uuid)
    )
  end

  test "uses safe relative return_to path" do
    params[:return_to] = "/cards?filter=assigned"
    params[:return_label] = "Assigned to Me"

    html = link_back_to_board(@board)

    assert_includes html, "/cards?filter=assigned"
    assert_includes html, "Assigned to Me"
  end

  test "rejects external url" do
    params[:return_to] = "https://evil.com"
    params[:return_label] = "Hacked"

    html = link_back_to_board(@board)

    assert_includes html, board_path(@board)
    assert_includes html, @board.name
  end

  test "rejects protocol relative url" do
    params[:return_to] = "//evil.com"

    html = link_back_to_board(@board)

    assert_includes html, board_path(@board)
  end

  test "rejects javascript scheme" do
    params[:return_to] = "javascript:alert(1)"

    html = link_back_to_board(@board)

    assert_includes html, board_path(@board)
  end

  test "falls back when params missing" do
    html = link_back_to_board(@board)

    assert_includes html, board_path(@board)
    assert_includes html, @board.name
  end
end