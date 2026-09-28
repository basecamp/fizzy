require "test_helper"

class Card::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "published cards are indexed" do
    card = @board.cards.create!(title: "Published Card", status: "published", creator: @user)
    assert_not_nil find_search_record(@account.id, type: "Card", id: card.id)
  end

  test "draft cards are not indexed" do
    card = @board.cards.create!(title: "Draft Card", status: "drafted", creator: @user)
    assert_nil find_search_record(@account.id, type: "Card", id: card.id)
  end

  test "card search" do
    # Searching by title
    card = @board.cards.create!(title: "layout is broken", status: "published", creator: @user)
    results = Card.mentioning("layout", user: @user)
    assert_includes results, card

    # Searching by comment
    card_with_comment = @board.cards.create!(title: "Some card", status: "published", creator: @user)
    card_with_comment.comments.create!(body: "overflowing text", creator: @user)
    results = Card.mentioning("overflowing", user: @user)
    assert_includes results, card_with_comment

    # Sanitizing search query
    card_broken = @board.cards.create!(title: "broken layout", status: "published", creator: @user)
    results = Card.mentioning("broken \"", user: @user)
    assert_includes results, card_broken

    # Empty query returns no results
    assert_empty Card.mentioning("\"", user: @user)

    # Filtering by board_ids
    other_board = Board.create!(name: "Other Board", account: @account, creator: @user)
    card_in_board = @board.cards.create!(title: "searchable content", status: "published", creator: @user)
    card_in_other_board = other_board.cards.create!(title: "searchable content", status: "published", creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_in_board
    assert_not_includes results, card_in_other_board
  end

  test "search content is truncated to a reasonable limit" do
    long_content = "asdf " * 8000
    assert_operator long_content.bytesize, :>, Card::SEARCH_CONTENT_LIMIT,
      "this test only bites when the description exceeds the limit"

    card = @board.cards.create!(title: "Card with long description", status: "published", creator: @user, description: long_content)

    content = indexed_content_for(@account.id, type: "Card", id: card.id)
    assert_predicate content, :present?
    assert_operator content.bytesize, :<=, Card::SEARCH_CONTENT_LIMIT
  end

  test "editing a description reindexes the card" do
    card = @board.cards.create!(title: "Card to edit", status: "published", creator: @user)
    card.update!(description: "kestrelbravo appears only after the edit")

    assert_includes Card.mentioning("kestrelbravo", user: @user), card
  end

  test "editing a comment body reindexes it" do
    card = @board.cards.create!(title: "Card with a comment", status: "published", creator: @user)
    comment = card.comments.create!(body: "original text", creator: @user)
    comment.update!(body: "kestrelcharlie appears only after the edit")

    assert_includes Card.mentioning("kestrelcharlie", user: @user), card
  end

  test "deleting card removes search record" do
    card = @board.cards.create!(title: "Card to delete", status: "published", creator: @user)

    # Verify search record exists
    search_record = find_search_record(@account.id, type: "Card", id: card.id)
    assert_not_nil search_record, "Search record should exist after card creation"

    # Delete the card
    card.destroy

    # Verify search record is deleted
    search_record = find_search_record(@account.id, type: "Card", id: card.id)
    assert_nil search_record, "Search record should be deleted after card deletion"
  end

  test "updating a draft card does not index it" do
    card = @board.cards.create!(title: "Draft card", creator: @user, status: "drafted")
    assert_nil find_search_record(@account.id, type: "Card", id: card.id)

    card.update!(title: "Updated draft card")
    assert_nil find_search_record(@account.id, type: "Card", id: card.id), "Draft card should not be indexed after update"

    results = Card.mentioning("Updated", user: @user)
    assert_not_includes results, card
  end

  test "publishing a draft card indexes it" do
    card = @board.cards.create!(title: "Draft to publish", creator: @user, status: "drafted")
    assert_nil find_search_record(@account.id, type: "Card", id: card.id)

    card.publish
    search_record = find_search_record(@account.id, type: "Card", id: card.id)
    assert_not_nil search_record, "Published card should be indexed"

    results = Card.mentioning("publish", user: @user)
    assert_includes results, card
  end

  test "unpublishing a draft card removes it from the search index" do
    card = @board.cards.create!(title: "Draft to publish", creator: @user, status: "published")
    assert_not_nil find_search_record(@account.id, type: "Card", id: card.id)

    card.update!(status: "drafted")

    assert_nil find_search_record(@account.id, type: "Card", id: card.id)
    results = Card.mentioning("publish", user: @user)
    assert_not_includes results, card
  end
end
