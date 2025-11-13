require "test_helper"

class Comment::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    @card = @board.cards.create!(title: "Test Card", creator: @user)
  end

  test "comment search" do
    # Comment is indexed on create
    comment = @card.comments.create!(body: "searchable comment text", creator: @user)
    record = Search::Record.for_account(@account.id).find_by(searchable_type: "Comment", searchable_id: comment.id)
    assert_not_nil record

    # Comment is updated in index
    comment.update!(body: "updated text")
    record = Search::Record.for_account(@account.id).find_by(searchable_type: "Comment", searchable_id: comment.id)
    assert_match /updat/, record.content

    # Comment is removed from index on destroy
    comment_id = comment.id
    comment.destroy
    record = Search::Record.for_account(@account.id).find_by(searchable_type: "Comment", searchable_id: comment_id)
    assert_nil record

    # Finding cards via comment search
    card_with_comment = @board.cards.create!(title: "Card One", creator: @user)
    card_with_comment.comments.create!(body: "unique searchable phrase", creator: @user)
    card_without_comment = @board.cards.create!(title: "Card Two", creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_with_comment
    assert_not_includes results, card_without_comment

    # Comment stores parent card_id and board_id
    new_comment = @card.comments.create!(body: "test comment", creator: @user)
    record = Search::Record.for_account(@account.id).find_by(searchable_type: "Comment", searchable_id: new_comment.id)
    assert_equal @card.id, record.card_id
    assert_equal @board.id, record.board_id
  end
end
