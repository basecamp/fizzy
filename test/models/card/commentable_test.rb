require "test_helper"

class Bubble::CommentableTest < ActiveSupport::TestCase
  test "creating a comment on a bubble makes the creator watch the bubble" do
    buckets(:writebook).access_for(users(:kevin)).access_only!
    assert_not bubbles(:text).watched_by?(users(:kevin))

    with_current_user(:kevin) do
      bubbles(:text).capture Comment.new(body: "This sounds interesting!")
    end

    assert bubbles(:text).watched_by?(users(:kevin))
  end
end
