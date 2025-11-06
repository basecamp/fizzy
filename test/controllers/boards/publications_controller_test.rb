require "test_helper"

class Boards::PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "publish a board" do
    assert_not @board.published?

    assert_changes -> { @board.reload.published? }, from: false, to: true do
      post board_publication_path(@board, format: :turbo_stream)
    end

    assert_turbo_stream action: :replace, target: dom_id(@board, :publication)
  end

  test "unpublish a board" do
    @board.publish
    assert @board.published?

    assert_changes -> { @board.reload.published? }, from: true, to: false do
      delete board_publication_path(@board, format: :turbo_streamn)
    end

    assert_turbo_stream action: :replace, target: dom_id(@board, :publication)
  end
end
