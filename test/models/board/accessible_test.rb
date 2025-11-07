require "test_helper"

class Board::AccessibleTest < ActiveSupport::TestCase
  test "revising access" do
    boards(:writebook).update! all_access: false

    boards(:writebook).accesses.revise granted: users(:david, :jz), revoked: users(:kevin)
    assert_equal users(:david, :jz), boards(:writebook).users

    boards(:writebook).accesses.grant_to users(:kevin)
    assert_includes boards(:writebook).users.reload, users(:kevin)

    boards(:writebook).accesses.revoke_from users(:kevin)
    assert_not_includes boards(:writebook).users.reload, users(:kevin)
  end

  test "grants access to everyone after creation" do
    board = Current.set(session: sessions(:david)) do
      Board.create! name: "New board", all_access: true
    end
    assert_equal User.active.sort, board.users.sort
  end

  test "grants access to everyone after update" do
    board = Current.set(session: sessions(:david)) do
      Board.create! name: "New board"
    end
    assert_equal [ users(:david) ], board.users

    board.update! all_access: true
    assert_equal User.active.sort, board.users.reload.sort
  end

  test "board watchers" do
    boards(:writebook).access_for(users(:kevin)).watching!
    assert_includes boards(:writebook).watchers, users(:kevin)

    boards(:writebook).access_for(users(:kevin)).access_only!
    assert_not_includes boards(:writebook).reload.watchers, users(:kevin)
  end

  # NOTE: The tests for clearing inaccessible data are in +AccessTest+
end
