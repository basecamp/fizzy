require "test_helper"

class Boards::ArchivedBoardUiTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  test "card page offers edit controls on an active board" do
    get card_path(@card)

    assert_select "a[href=?]", edit_card_path(@card)
    assert_select "a[href=?]", edit_card_comment_path(@card, comments(:logo_agreement_kevin))
    assert_select "form[action=?] button:not([disabled])", card_closure_path(@card)
    assert_select "form[action=?]", card_comments_path(@card)
    assert_select ".reactions__trigger"
  end

  test "card page disables edit controls on an archived board" do
    @board.archive

    get card_path(@card)
    assert_response :success

    assert_select "a[href=?]", edit_card_path(@card), count: 0
    assert_select "form[action=?] button[disabled]", card_closure_path(@card)
    assert_select "form[action=?] button[disabled]", card_goldness_path(@card)
    assert_select "form[action=?]", card_steps_path(@card), count: 0
    assert_select "form[action=?]", card_comments_path(@card), count: 0
    assert_select "a[href=?]", edit_card_comment_path(@card, comments(:logo_agreement_kevin)), count: 0
    assert_select ".reactions__trigger", count: 0
    assert_select ".card__tag-picker-button[disabled]"
    assert_select ".card__assignees-trigger[disabled]"
    assert_select "form[action=?]", card_self_assignment_path(@card), count: 0
    assert_select "form[action=?]", card_path(@card), count: 0
  end

  test "column picker is disabled on an archived board" do
    @board.archive

    get edit_card_column_path(@card)
    assert_response :success

    assert_select ".card__column-name"
    assert_select ".card__column-name:not([disabled])", count: 0
  end

  test "board page hides column editing on an archived board" do
    column = @board.columns.sorted.last

    get board_path(@board)
    assert_select "[data-controller~=card-hotkeys]"
    assert_select "form[action=?]", column_left_position_path(column)

    @board.archive

    get board_path(@board)
    assert_select "[data-controller~=card-hotkeys]", count: 0
    assert_select "form[action=?]", column_left_position_path(column), count: 0
    assert_select "[data-controller~=drag-and-drop]", count: 0
    assert_select "form[action=?]", board_cards_path(@board), count: 0
  end

  test "board settings are disabled on an archived board" do
    @board.archive

    get edit_board_path(@board)
    assert_response :success

    assert_select "input[name=?][readonly]", "board[name]"
    assert_select "button#log_in[disabled]"
    assert_select "input#board_all_access[disabled]"
    assert_select "button", text: /Unarchive this board/
  end
end
