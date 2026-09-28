require "test_helper"

class Card::BoardMoveSearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    User.create!(name: "System", account: @account, role: :system)
    @owner = User.create!(name: "Owner", account: @account,
                          identity: Identity.create!(email_address: "owner@example.com"))
    @private_board = Board.create!(name: "Private Board", account: @account, creator: @owner)
  end

  test "a comment stops being searchable when its card moves to a board you cannot see" do
    card = @board.cards.create!(title: "kestrelcard", status: "published", creator: @user)
    card.comments.create!(body: "kestrelbody secret", creator: @user)

    assert_not_includes @user.board_ids, @private_board.id
    assert_equal 1, @user.search("kestrelbody").results.to_a.size

    perform_enqueued_jobs { card.update!(board: @private_board) }

    assert_empty @user.reload.search("kestrelbody").results.to_a,
      "a comment stayed searchable under the board its card left"
  end

  test "a comment becomes searchable in the board its card moved to" do
    card = @board.cards.create!(title: "kestrelcard", status: "published", creator: @user)
    card.comments.create!(body: "kestrelbody secret", creator: @user)

    perform_enqueued_jobs { card.update!(board: @private_board) }

    assert_equal 1, @owner.reload.search("kestrelbody").results.to_a.size,
      "a comment did not follow its card to the new board"
  end
end
