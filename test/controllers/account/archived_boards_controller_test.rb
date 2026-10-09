require "test_helper"

class Account::ArchivedBoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "account settings link to the archived boards" do
    get account_settings_path
    assert_select "a[href=?]", account_archived_boards_path
  end

  test "index lists only archived boards" do
    boards(:writebook).archive

    get account_archived_boards_path
    assert_response :success
    assert_select "a[href=?]", board_path(boards(:writebook))
    assert_select "form[action=?]", board_archival_path(boards(:writebook))
    assert_select "a[href=?]", board_path(boards(:private)), count: 0
  end

  test "index without archived boards" do
    get account_archived_boards_path
    assert_response :success
    assert_select "p", text: "There are no archived boards."
  end

  test "unarchive is disabled for boards you can't administer" do
    boards(:writebook).archive
    logout_and_sign_in_as :jz

    get account_archived_boards_path
    assert_select "form[action=?] button[disabled]", board_archival_path(boards(:writebook))
  end

  test "index excludes archived boards you can't access" do
    boards(:private).archive
    logout_and_sign_in_as :david

    get account_archived_boards_path
    assert_select "a[href=?]", board_path(boards(:private)), count: 0
  end
end
