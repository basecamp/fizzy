require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_board_path
    assert_response :success
  end

  test "show" do
    get board_path(boards(:writebook))
    assert_response :success
  end

  test "create" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "Remodel Punch List" } }
    end

    board = Board.order(created_at: :desc).first
    assert_redirected_to board_path(board)
    assert_includes board.users, users(:kevin)
    assert_equal "Remodel Punch List", board.name
  end

  test "edit" do
    get edit_board_path(boards(:writebook))
    assert_response :success
  end

  test "update" do
    patch board_path(boards(:writebook)), params: {
      board: {
        name: "Writebook bugs",
        all_access: false,
        auto_postpone_period: 1.day
      },
      user_ids: users(:kevin, :jz).pluck(:id)
    }

    assert_redirected_to edit_board_path(boards(:writebook))
    assert_equal "Writebook bugs", boards(:writebook).reload.name
    assert_equal users(:kevin, :jz).sort, boards(:writebook).users.sort
    assert_equal 1.day, entropies(:writebook_board).auto_postpone_period
    assert_not boards(:writebook).all_access?
  end

  test "update redirects to root when user removes themselves from board" do
    board = boards(:writebook)

    patch board_path(board), params: {
      board: { name: "Updated name", all_access: false },
      user_ids: users(:david, :jz).pluck(:id)
    }

    assert_redirected_to root_path
    assert_not board.reload.users.include?(users(:kevin))
  end

  test "update board with granular permissions, submitting no user ids" do
    assert_not boards(:private).all_access?

    boards(:private).users = [ users(:kevin) ]
    boards(:private).save!

    patch board_path(boards(:private)), params: {
      board: { name: "Renamed" }
    }

    assert_redirected_to edit_board_path(boards(:private))
    assert_equal "Renamed", boards(:private).reload.name
    assert_equal [ users(:kevin) ], boards(:private).users
    assert_not boards(:private).all_access?
  end

  test "update all access" do
    board = Current.set(session: sessions(:kevin)) do
      Board.create! name: "New board", all_access: false
    end
    assert_equal [ users(:kevin) ], board.users

    patch board_path(board), params: { board: { name: "Bugs", all_access: true } }

    assert_redirected_to edit_board_path(board)
    assert board.reload.all_access?
    assert_equal accounts("37s").users.active.sort, board.users.sort
  end

  test "destroy" do
    board = boards(:writebook)
    delete board_path(board)
    assert_redirected_to root_path
    assert_raises(ActiveRecord::RecordNotFound) { board.reload }
  end

  test "non-admin cannot change all_access on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_all_access = board.all_access

    patch board_path(board), params: { board: { all_access: !original_all_access } }

    assert_response :forbidden
    assert_equal original_all_access, board.reload.all_access
  end

  test "non-admin cannot change individual user accesses on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_users = board.users.sort

    patch board_path(board), params: {
      board: { name: board.name },
      user_ids: [ users(:jz).id ]
    }

    assert_response :forbidden
    assert_equal original_users, board.reload.users.sort
  end

  test "non-admin cannot change board name on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_name = board.name

    patch board_path(board), params: {
      board: { name: "Hacked Board Name" }
    }

    assert_response :forbidden
    assert_equal original_name, board.reload.name
  end
end
