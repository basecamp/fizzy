require "test_helper"

class Boards::InvolvementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    board = boards(:writebook)
    board.access_for(users(:kevin)).access_only!

    assert_changes -> { board.access_for(users(:kevin)).involvement }, from: "access_only", to: "watching" do
      put board_involvement_path(board, involvement: "watching")
    end

    assert_response :success
  end

  test "update as JSON" do
    board = boards(:writebook)
    board.access_for(users(:kevin)).access_only!

    assert_changes -> { board.access_for(users(:kevin)).involvement }, from: "access_only", to: "watching" do
      put board_involvement_path(board), params: { involvement: "watching" }, as: :json
    end

    assert_response :no_content
  end

  test "update as turbo stream replaces the involvement frame" do
    board = boards(:writebook)
    board.access_for(users(:kevin)).access_only!

    assert_changes -> { board.access_for(users(:kevin)).involvement }, from: "access_only", to: "watching" do
      put board_involvement_path(board), params: { involvement: "watching", show_watchers: "true" },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml", "Turbo-Frame" => dom_id(board, :involvement_button) }
    end

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame##{dom_id(board, :involvement_button)}" do
      assert_select ".board-tools__watching a.avatar[aria-label=?]", users(:kevin).name
      assert_select "button", text: /Stop watching/
    end
  end
end
