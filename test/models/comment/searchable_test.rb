require "test_helper"

class Comment::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    @card = @board.cards.create!(title: "Test Card", status: "published", creator: @user)
  end

  test "searchable? returns true for comments on published cards" do
    comment = @card.comments.create!(body: "test comment", creator: @user)
    assert comment.searchable?
  end

  test "searchable? returns false for comments on draft cards" do
    draft_card = @board.cards.create!(title: "Draft Card", status: "drafted", creator: @user)
    comment = draft_card.comments.build(body: "test comment", creator: @user)
    assert_not comment.searchable?
  end

  test "comment search" do
    search_record_class = Search::Record.for(@user.account_id)
    # Comment is indexed on create
    comment = @card.comments.create!(body: "searchable comment text", creator: @user)
    record = search_record_class.find_by(searchable_type: "Comment", searchable_id: comment.id)
    assert_not_nil record

    # Comment is updated in index
    comment.update!(body: "updated text")
    record = search_record_class.find_by(searchable_type: "Comment", searchable_id: comment.id)
    assert_match /updat/, record.content

    # Comment is removed from index on destroy
    comment_id = comment.id
    search_record_id = record.id

    # For SQLite, verify FTS entry exists before deletion
    if search_record_class.connection.adapter_name == "SQLite"
      fts_entry = record.search_records_fts
      assert_not_nil fts_entry, "FTS entry should exist before comment deletion"
    end

    comment.destroy
    record = search_record_class.find_by(searchable_type: "Comment", searchable_id: comment_id)
    assert_nil record

    # For SQLite, verify FTS entry is also deleted
    if search_record_class.connection.adapter_name == "SQLite"
      fts_count = Search::Record::SQLite::Fts.where(rowid: search_record_id).count
      assert_equal 0, fts_count, "FTS entry should be deleted after comment deletion"
    end

    # Finding cards via comment search
    card_with_comment = @board.cards.create!(title: "Card One", status: "published", creator: @user)
    card_with_comment.comments.create!(body: "unique searchable phrase", creator: @user)
    card_without_comment = @board.cards.create!(title: "Card Two", status: "published", creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_with_comment
    assert_not_includes results, card_without_comment

    # Comment stores parent card_id and board_id
    new_comment = @card.comments.create!(body: "test comment", creator: @user)
    record = search_record_class.find_by(searchable_type: "Comment", searchable_id: new_comment.id)
    assert_equal @card.id, record.card_id
    assert_equal @board.id, record.board_id
  end
end
