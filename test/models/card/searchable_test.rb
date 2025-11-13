require "test_helper"

class Card::SearchableTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    16.times { |i| ActiveRecord::Base.connection.execute "DELETE FROM search_index_#{i}" }
    Account.find_by(name: "Search Test")&.destroy

    @account = Account.create!(name: "Search Test")
    @user = User.create!(name: "Test User", account: @account)
    @board = Board.create!(name: "Test Board", account: @account, creator: @user)
    Current.account = @account
  end

  teardown do
    16.times { |i| ActiveRecord::Base.connection.execute "DELETE FROM search_index_#{i}" }
    Account.find_by(name: "Search Test")&.destroy
  end

  test "card search" do
    # Searching by title
    card = @board.cards.create!(title: "layout is broken", creator: @user)
    results = Card.mentioning("layout", user: @user)
    assert_includes results, card

    # Searching by comment
    card_with_comment = @board.cards.create!(title: "Some card", creator: @user)
    card_with_comment.comments.create!(body: "overflowing text", creator: @user)
    results = Card.mentioning("overflowing", user: @user)
    assert_includes results, card_with_comment

    # Sanitizing search query
    card_broken = @board.cards.create!(title: "broken layout", creator: @user)
    results = Card.mentioning("broken \"", user: @user)
    assert_includes results, card_broken

    # Empty query returns no results
    assert_empty Card.mentioning("\"", user: @user)

    # Filtering by board_ids
    other_board = Board.create!(name: "Other Board", account: @account, creator: @user)
    card_in_board = @board.cards.create!(title: "searchable content", creator: @user)
    card_in_other_board = other_board.cards.create!(title: "searchable content", creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_in_board
    assert_not_includes results, card_in_other_board
  end
end
