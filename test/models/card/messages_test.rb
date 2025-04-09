require "test_helper"

class Bubble::MessagesTest < ActiveSupport::TestCase
  test "creating a bubble does not create a message by default" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "New"

    assert_empty bubble.messages
  end

  test "creating a bubble with an initial draft comment" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    assert_equal 1, bubble.messages.count
    assert_equal "This is a comment", bubble.draft_comment.strip
  end

  test "updating the draft comment" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    bubble.update! draft_comment: "This is an updated comment"

    assert_equal 1, bubble.messages.count
    assert_equal "This is an updated comment", bubble.draft_comment.strip
  end

  test "setting the draft comment to be blank removes it" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    bubble.update! draft_comment: " "

    assert bubble.messages.first.nil?
  end

  test "omitting the draft comment does not remove it" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "New",
      draft_comment: "This is a comment"

    bubble.update! title: "Newer"

    assert_equal 1, bubble.messages.count
    assert_equal "This is a comment", bubble.draft_comment.strip
  end
end
