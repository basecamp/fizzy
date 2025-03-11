require "test_helper"

class Bubble::ScorableTest < ActiveSupport::TestCase
  test "a bubble has a score that increases with activity" do
    bubble = bubbles(:logo)

    score = bubble.activity_score
    assert_operator score, :>, 0

    with_current_user :kevin do
      bubble.capture Comment.create(body: "This is exciting!")
    end

    assert_operator bubble.activity_score, :>, score
  end

  test "commenting on a bubble boosts its score more than boosting it" do
    bubble = bubbles(:logo)
    bubble.rescore

    comment_change = capture_change -> { bubble.activity_score } do
      with_current_user :kevin do
        bubble.capture Comment.create(body: "This is exciting!")
      end
    end

    boost_change = capture_change -> { bubble.activity_score } do
      with_current_user :kevin do
        bubble.boost!
      end
    end

    assert_operator comment_change, :>, boost_change
  end

  test "recent activity counts more than older activity in the ordering" do
    with_current_user :kevin do
      travel_to 5.days.ago
      bubble_old = buckets(:writebook).bubbles.create! status: :published, title: "old"
      bubble_mid = buckets(:writebook).bubbles.create! status: :published, title: "mid"
      bubble_new = buckets(:writebook).bubbles.create! status: :published, title: "new"

      bubble_old.boost!
      bubble_old.boost!

      travel_back
      travel_to 2.days.ago
      bubble_mid.boost!

      travel_back
      bubble_new.boost!

      assert_equal [ bubble_new, bubble_mid, bubble_old ], Bubble.where(id: [ bubble_old, bubble_mid, bubble_new ]).ordered_by_activity
    end
  end

  test "bubbles with no activity have a valid activity_score_order" do
    bubble = Bubble.create! bucket: buckets(:writebook), creator: users(:kevin)

    bubble.rescore

    assert bubble.activity_score.zero?
    assert_not bubble.activity_score_order.infinite?
  end
end
