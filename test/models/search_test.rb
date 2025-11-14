require "test_helper"

class SearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "search" do
    # Search cards and comments
    card = @board.cards.create!(title: "layout design", creator: @user)
    comment_card = @board.cards.create!(title: "Some card", creator: @user)
    comment_card.comments.create!(body: "overflowing text", creator: @user)

    results = Search.results(query: "layout", user: @user)
    assert results.find { |it| it.card_id == card.id }

    results = Search.results(query: "overflowing", user: @user)
    assert results.find { |it| it.card_id == comment_card.id && it.searchable_type == "Comment" }

    # Don't include inaccessible boards
    other_user = User.create!(name: "Other User", account: @account)
    inaccessible_board = Board.create!(name: "Inaccessible Board", account: @account, creator: other_user)
    accessible_card = @board.cards.create!(title: "searchable content", creator: @user)
    inaccessible_card = inaccessible_board.cards.create!(title: "searchable content", creator: other_user)

    results = Search.results(query: "searchable", user: @user)
    assert results.find { |it| it.card_id == accessible_card.id }
    assert_not results.find { |it| it.card_id == inaccessible_card.id }

    # Empty board_ids returns no results
    user_without_access = User.create!(name: "No Access User", account: @account)
    results = Search.results(query: "anything", user: user_without_access)
    assert_empty results
  end
end
