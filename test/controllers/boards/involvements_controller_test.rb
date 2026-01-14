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

  test "update via JSON returns no content" do
    board = boards(:writebook)
    board.access_for(users(:kevin)).access_only!

    assert_changes -> { board.access_for(users(:kevin)).involvement }, from: "access_only", to: "watching" do
      put board_involvement_path(board, involvement: "watching"), as: :json
    end

    assert_response :no_content
  end
end
