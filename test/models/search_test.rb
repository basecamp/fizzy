require "test_helper"

class SearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "search" do
    # Search cards and comments
    card = @board.cards.create!(title: "layout design", creator: @user, status: "published")
    comment_card = @board.cards.create!(title: "Some card", creator: @user, status: "published")
    comment_card.comments.create!(body: "overflowing text", creator: @user)

    results = Search::Record.for(@user.account_id).search("layout", user: @user)
    assert results.find { |it| it.card_id == card.id }

    results = Search::Record.for(@user.account_id).search("overflowing", user: @user)
    assert results.find { |it| it.card_id == comment_card.id && it.searchable_type == "Comment" }

    # Drafted cards are excluded from search results
    drafted_card = @board.cards.create!(title: "drafted searchable content", creator: @user, status: "drafted")
    results = Search::Record.for(@user.account_id).search("drafted", user: @user)
    assert_not results.find { |it| it.card_id == drafted_card.id }

    # Don't include inaccessible boards
    other_user = User.create!(name: "Other User", account: @account)
    inaccessible_board = Board.create!(name: "Inaccessible Board", account: @account, creator: other_user)
    accessible_card = @board.cards.create!(title: "searchable content", creator: @user, status: "published")
    inaccessible_card = inaccessible_board.cards.create!(title: "searchable content", creator: other_user, status: "published")

    results = Search::Record.for(@user.account_id).search("searchable", user: @user)
    assert results.find { |it| it.card_id == accessible_card.id }
    assert_not results.find { |it| it.card_id == inaccessible_card.id }

    # Empty board_ids returns no results
    user_without_access = User.create!(name: "No Access User", account: @account)
    results = Search::Record.for(user_without_access.account_id).search("anything", user: user_without_access)
    assert_empty results
  end
end
