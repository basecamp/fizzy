require "test_helper"

class Card::CommentableTest < ActiveSupport::TestCase
  test "creating a comment on a card makes the creator watch the card" do
    collections(:writebook).access_for(users(:kevin)).access_only!
    assert_not cards(:text).watched_by?(users(:kevin))

    with_current_user(:kevin) do
      cards(:text).capture Comment.new(body: "This sounds interesting!")
    end

    assert cards(:text).watched_by?(users(:kevin))
  end
end
