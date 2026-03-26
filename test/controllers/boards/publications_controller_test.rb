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
      delete board_publication_path(@board, format: :turbo_stream)
    end

    assert_turbo_stream action: :replace, target: dom_id(@board, :publication)
  end

  test "publish a board via JSON" do
    assert_not @board.published?

    assert_changes -> { @board.reload.published? }, from: false, to: true do
      post board_publication_path(@board), as: :json
    end

    assert_response :created
    body = @response.parsed_body
    @board.reload
    assert_equal @board.name, body["name"]
    assert_equal published_board_url(@board), body["public_url"]
  end

  test "unpublish a board via JSON" do
    @board.publish
    assert @board.published?

    assert_changes -> { @board.reload.published? }, from: true, to: false do
      delete board_publication_path(@board), as: :json
    end

    assert_response :no_content
  end

  test "publish requires board admin permission" do
    logout_and_sign_in_as :jz

    assert_not @board.published?

    post board_publication_path(@board, format: :turbo_stream)

    assert_response :forbidden
    assert_not @board.reload.published?
  end

  test "unpublish requires board admin permission" do
    logout_and_sign_in_as :jz

    @board.publish
    assert @board.published?

    delete board_publication_path(@board, format: :turbo_stream)

    assert_response :forbidden
    assert @board.reload.published?
  end
end
