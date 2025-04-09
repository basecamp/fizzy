require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "searchable by body" do
    message = cards(:logo).capture Comment.new(body: "I'd prefer something more rustic")

    assert_includes Comment.search("something rustic"), message.comment
  end

  test "updating card counter" do
    assert_difference -> { cards(:logo).comments_count } do
      assert_changes -> { cards(:logo).activity_score } do
        cards(:logo).capture Comment.new(body: "I'd prefer something more rustic")
      end
    end

    assert_difference -> { cards(:logo).comments_count }, -1 do
      assert_changes -> { cards(:logo).activity_score } do
        cards(:logo).messages.comments.last.destroy
      end
    end
  end

  test "first_by_author_on_card?" do
    assert_not Comment.new.first_by_author_on_card?

    with_current_user :david do
      comment = Comment.new.tap { |c| cards(:logo).capture c }
      assert comment.first_by_author_on_card?

      comment = Comment.new.tap { |c| cards(:logo).capture c }
      assert_not comment.first_by_author_on_card?
    end

    with_current_user :kevin do
      comment = Comment.new.tap { |c| cards(:logo).capture c }
      assert_not comment.first_by_author_on_card?
    end
  end

  test "follows_comment_by_another_author?" do
    assert_not Comment.new.follows_comment_by_another_author?

    card = collections(:writebook).cards.create!

    with_current_user :david do
      comment = Comment.new.tap { |c| card.capture c }
      assert_not comment.follows_comment_by_another_author?
    end

    with_current_user :kevin do
      comment = Comment.new.tap { |c| card.capture c }
      assert comment.follows_comment_by_another_author?
    end

    with_current_user :david do
      comment = Comment.new.tap { |c| card.capture c }
      assert comment.follows_comment_by_another_author?
    end
  end
end
