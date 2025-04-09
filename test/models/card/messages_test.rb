require "test_helper"

class Card::MessagesTest < ActiveSupport::TestCase
  test "creating a card does not create a message by default" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "New"

    assert_empty card.messages
  end

  test "creating a card with an initial draft comment" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    assert_equal 1, card.messages.count
    assert_equal "This is a comment", card.draft_comment.strip
  end

  test "updating the draft comment" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    card.update! draft_comment: "This is an updated comment"

    assert_equal 1, card.messages.count
    assert_equal "This is an updated comment", card.draft_comment.strip
  end

  test "setting the draft comment to be blank removes it" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    card.update! draft_comment: " "

    assert card.messages.first.nil?
  end

  test "omitting the draft comment does not remove it" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    card.update! title: "Newer"

    assert_equal 1, card.messages.count
    assert_equal "This is a comment", card.draft_comment.strip
  end
end
