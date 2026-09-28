require "test_helper"

class SearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "unpublishing removes a card already in the index" do
    card = @board.cards.create!(title: "reversible kestrelword", creator: @user, status: "published")
    assert_equal 1, @user.search("kestrelword").results.to_a.size, "precondition: published card is searchable"

    card.update!(status: "drafted")

    assert_empty @user.reload.search("kestrelword").results.to_a,
      "a card unpublished after indexing should leave the index"
  end

  test "search" do
    # Search cards and comments
    card = @board.cards.create!(title: "layout design", creator: @user, status: "published")
    comment_card = @board.cards.create!(title: "Some card", creator: @user, status: "published")
    comment_card.comments.create!(body: "overflowing text", creator: @user)

    results = @user.search("layout").results
    assert results.find { |it| it.is_a?(Card) && it.id == card.id }

    results = @user.search("overflowing").results
    assert results.find { |it| it.is_a?(Comment) && it.card_id == comment_card.id }

    # Drafted cards are excluded from search results
    drafted_card = @board.cards.create!(title: "drafted searchable content", creator: @user, status: "drafted")
    results = @user.search("drafted").results
    assert_not results.find { |it| it.is_a?(Card) && it.id == drafted_card.id }

    # Don't include inaccessible boards
    other_user = User.create!(name: "Other User", account: @account)
    inaccessible_board = Board.create!(name: "Inaccessible Board", account: @account, creator: other_user)
    accessible_card = @board.cards.create!(title: "searchable content", creator: @user, status: "published")
    inaccessible_card = inaccessible_board.cards.create!(title: "searchable content", creator: other_user, status: "published")

    results = @user.search("searchable").results
    card_ids = results.map { |r| r.is_a?(Card) ? r.id : r.card_id }
    assert_includes card_ids, accessible_card.id
    assert_not_includes card_ids, inaccessible_card.id

    # Empty board_ids returns no results. The term has to be one the account does match,
    # or this passes with the board filter gone.
    user_without_access = User.create!(name: "No Access User", account: @account)
    assert_empty user_without_access.board_ids, "precondition: the user reaches no board"
    assert_not_empty @user.search("searchable").results, "control: the term matches for a user who can see the boards"
    assert_empty user_without_access.search("searchable").results
  end

  test "results come back newest first" do
    oldest = @board.cards.create!(title: "chronology marker", creator: @user, status: "published", created_at: 3.days.ago)
    middle = @board.cards.create!(title: "chronology marker", creator: @user, status: "published", created_at: 2.days.ago)
    newest = @board.cards.create!(title: "chronology marker", creator: @user, status: "published", created_at: 1.day.ago)

    assert_equal [ newest, middle, oldest ].map(&:id), @user.search("chronology").results.map(&:id)
  end

  test "search for hyphenated strings" do
    card = @board.cards.create!(title: "BC3-IOS-1D8B", creator: @user, status: "published")

    results = @user.search("BC3-IOS-1D8B").results
    assert results.find { |it| it.is_a?(Card) && it.id == card.id }
  end

  test "mentioning is not capped by the default search limit" do
    30.times { |i| @board.cards.create!(title: "capped card #{i}", creator: @user, status: "published") }

    assert_operator Rails.application.config.active_search.default_limit, :<, 30,
      "this test only bites above the default limit"
    assert_equal 30, Card.mentioning("capped", user: @user).distinct.count
  end

  test "search_relation returns a relation Card.mentioning can compose" do
    card = @board.cards.create!(title: "composable haggis", creator: @user, status: "published")

    relation = @user.search_relation("haggis")
    assert_kind_of ActiveRecord::Relation, relation
    assert_match(/\Asearch_records/, relation.model.table_name)
    assert_kind_of ActiveRecord::Relation, relation.except(:select, :order)

    table = relation.model.table_name
    merged = Card.joins("INNER JOIN #{table} ON #{table}.card_id = cards.id")
                 .merge(relation.except(:select, :order))
    assert_includes merged, card
  end
end
