require "test_helper"

class MentionTest < ActiveSupport::TestCase
  test "high_priority_push? is always true" do
    mention = mentions(:logo_card_david_mention_by_jz)

    assert mention.high_priority_push?
  end

  test "high_priority_push? is true for comment mentions" do
    mention = mentions(:logo_comment_david_mention_by_jz)

    assert mention.high_priority_push?
  end
end
