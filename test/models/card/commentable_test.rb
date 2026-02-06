require "test_helper"

class Card::CommentableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "capturing comments" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      cards(:logo).comments.create!(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).comments.last.body.to_plain_text.chomp
  end

  test "creating a comment on a card makes the creator watch the card" do
    boards(:writebook).access_for(users(:kevin)).access_only!
    assert_not cards(:text).watched_by?(users(:kevin))

    with_current_user(:kevin) do
      cards(:text).comments.create!(body: "This sounds interesting!")
    end

    assert cards(:text).watched_by?(users(:kevin))
  end

  test "commentable is true for published cards, false for drafts" do
    assert cards(:logo).commentable?
    assert_not cards(:unfinished_thoughts).commentable?
  end
end
