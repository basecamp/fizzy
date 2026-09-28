require "test_helper"

class Comment::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    @card = @board.cards.create!(title: "Test Card", status: "published", creator: @user)
  end

  test "comments on published cards are indexed" do
    comment = @card.comments.create!(body: "test comment", creator: @user)
    assert_not_nil find_search_record(@account.id, type: "Comment", id: comment.id)
  end

  test "unpublishing a card leaves its comments indexed until they are reindexed" do
    card = @board.cards.create!(title: "Card to draft", status: "published", creator: @user)
    comment = card.comments.create!(body: "test comment", creator: @user)
    assert_not_nil find_search_record(@account.id, type: "Comment", id: comment.id)

    card.update!(status: "drafted")
    assert_not_nil find_search_record(@account.id, type: "Comment", id: comment.id)

    card.reindex_comments
    assert_nil find_search_record(@account.id, type: "Comment", id: comment.id)
  end

  test "comment search" do
    # Comment is indexed on create
    comment = @card.comments.create!(body: "searchable comment text", creator: @user)
    record = find_search_record(@account.id, type: "Comment", id: comment.id)
    assert_not_nil record

    # Comment is updated in index
    comment.update!(body: "updated text")
    assert_equal [ comment ], @user.search("updated").results.to_a
    assert_empty @user.search("searchable").results.to_a

    # Comment is removed from index on destroy
    comment_id = comment.id
    comment.destroy
    record = find_search_record(@account.id, type: "Comment", id: comment_id)
    assert_nil record, "Search record should be deleted after comment deletion"

    # Finding cards via comment search
    card_with_comment = @board.cards.create!(title: "Card One", status: "published", creator: @user)
    card_with_comment.comments.create!(body: "unique searchable phrase", creator: @user)
    card_without_comment = @board.cards.create!(title: "Card Two", status: "published", creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_with_comment
    assert_not_includes results, card_without_comment

    # Comment stores parent card_id and board_id
    new_comment = @card.comments.create!(body: "test comment", creator: @user)
    record = find_search_record(@account.id, type: "Comment", id: new_comment.id)
    assert_equal @card.id, record.card_id
    assert_equal @board.id, record.board_id
  end

  test "reindexing clears a stored column the document does not supply" do
    skip "SQLite keeps text fields in the FTS table, not the record row" unless sharded_search?

    comment = @card.comments.create!(body: "clears absent columns", creator: @user)
    record = find_search_record(@account.id, type: "Comment", id: comment.id)
    assert_not_nil record

    search_shard_for(@account.id).where(id: record.id).update_all(title: "stale title")
    assert_equal "stale title", find_search_record(@account.id, type: "Comment", id: comment.id).title

    comment.reindex

    assert_nil find_search_record(@account.id, type: "Comment", id: comment.id).title
  end
end
