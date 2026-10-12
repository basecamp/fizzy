require "test_helper"

class Boards::ArchivalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "archive a board" do
    assert_changes -> { @board.reload.archived? }, from: false, to: true do
      post board_archival_path(@board)
    end

    assert_redirected_to board_path(@board)
    assert_equal users(:kevin), @board.archived_by
  end

  test "unarchive a board" do
    @board.archive

    assert_changes -> { @board.reload.archived? }, from: true, to: false do
      delete board_archival_path(@board)
    end

    assert_redirected_to board_path(@board)
  end

  test "archive a board via JSON" do
    assert_changes -> { @board.reload.archived? }, from: false, to: true do
      post board_archival_path(@board), as: :json
    end

    assert_response :created
    assert @response.parsed_body["archived"]
  end

  test "unarchive a board via JSON" do
    @board.archive

    assert_changes -> { @board.reload.archived? }, from: true, to: false do
      delete board_archival_path(@board), as: :json
    end

    assert_response :no_content
  end

  test "archive requires board admin permission" do
    logout_and_sign_in_as :jz

    post board_archival_path(@board)

    assert_response :forbidden
    assert_not @board.reload.archived?
  end

  test "unarchive requires board admin permission" do
    @board.archive
    logout_and_sign_in_as :jz

    delete board_archival_path(@board)

    assert_response :forbidden
    assert @board.reload.archived?
  end

  test "archived boards can still be viewed" do
    @board.archive

    get board_path(@board)
    assert_response :success
    assert_select "button", text: /Unarchive/

    get card_path(cards(:logo))
    assert_response :success
  end

  test "archived boards are read-only" do
    @board.archive

    assert_no_difference -> { Card.count } do
      post board_cards_path(@board), as: :json, params: { card: { title: "New card" } }
    end
    assert_response :forbidden

    put card_path(cards(:logo)), as: :json, params: { card: { title: "Renamed" } }
    assert_response :forbidden
    assert_not_equal "Renamed", cards(:logo).reload.title

    assert_no_difference -> { Comment.count } do
      post card_comments_path(cards(:logo)), as: :json, params: { comment: { body: "Hello" } }
    end
    assert_response :forbidden

    put board_path(@board), as: :json, params: { board: { name: "Renamed" } }
    assert_response :forbidden
    assert_not_equal "Renamed", @board.reload.name
  end

  test "cards can't be moved into or out of an archived board" do
    @board.archive

    put card_board_path(cards(:logo)), params: { board_id: boards(:private).id }
    assert_response :forbidden
    assert_equal @board, cards(:logo).reload.board

    @board.unarchive
    boards(:private).archive

    put card_board_path(cards(:logo)), params: { board_id: boards(:private).id }
    assert_response :forbidden
    assert_equal @board, cards(:logo).reload.board
  end

  test "archived boards can still be deleted" do
    @board.archive

    assert_difference -> { Board.count }, -1 do
      delete board_path(@board)
    end
  end

  test "archived boards are listed separately in the boards API" do
    @board.archive

    get boards_path, as: :json
    assert_not_includes @response.parsed_body.pluck("id"), @board.id

    get boards_path(archived: true), as: :json
    assert_equal [ @board.id ], @response.parsed_body.pluck("id")
  end

  test "settings offer to unarchive an archived board" do
    get edit_board_path(@board)
    assert_select "button", text: /Archive this board/

    @board.archive

    get edit_board_path(@board)
    assert_select "button", text: /Unarchive this board/
  end

  test "archived boards are left out of the menu" do
    @board.archive

    get my_menu_path
    assert_select "a[href=?]", board_path(@board), count: 0
  end

  test "unarchiving from the archived boards page returns there" do
    @board.archive

    delete board_archival_path(@board), headers: { "Referer" => account_archived_boards_url }

    assert_redirected_to account_archived_boards_url
    assert_not @board.reload.archived?
  end

  test "published archived boards are not publicly reachable" do
    @board.publish
    @board.archive

    get published_board_path(@board)
    assert_response :not_found
  end
end
