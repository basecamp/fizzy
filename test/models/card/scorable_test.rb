require "test_helper"

class Card::ScorableTest < ActiveSupport::TestCase
  test "a card has a score that increases with activity" do
    card = cards(:logo)

    score = card.activity_score
    assert_operator score, :>, 0

    with_current_user :kevin do
      card.capture Comment.create(body: "This is exciting!")
    end

    assert_operator card.activity_score, :>, score
  end

  test "commenting on a card boosts its score more than boosting it" do
    card = cards(:logo)
    card.rescore

    comment_change = capture_change -> { card.activity_score } do
      with_current_user :kevin do
        card.capture Comment.create(body: "This is exciting!")
      end
    end

    boost_change = capture_change -> { card.activity_score } do
      with_current_user :kevin do
        card.boost!
      end
    end

    assert_operator comment_change, :>, boost_change
  end

  test "recent activity counts more than older activity in the ordering" do
    with_current_user :kevin do
      travel_to 5.days.ago
      card_old = collections(:writebook).cards.create! status: :published, title: "old"
      card_mid = collections(:writebook).cards.create! status: :published, title: "mid"
      card_new = collections(:writebook).cards.create! status: :published, title: "new"

      card_old.boost!
      card_old.boost!

      travel_back
      travel_to 2.days.ago
      card_mid.boost!

      travel_back
      card_new.boost!

      assert_equal %w[ new mid old ], Card.where(id: [ card_old, card_mid, card_new ]).ordered_by_activity.map(&:title)
    end
  end

  test "items with old activity are more stale than those with none, or with new activity" do
    with_current_user :kevin do
      travel_to 20.days.ago
      card_old = collections(:writebook).cards.create! status: :published, title: "old"
      card_new = collections(:writebook).cards.create! status: :published, title: "new"
      card_none = collections(:writebook).cards.create! status: :published, title: "none"

      card_old.boost!
      card_old.boost!

      travel_back
      travel_to 2.days.ago
      card_new.boost!
      card_new.boost!

      travel_back

      assert_equal %w[ old new none ], Card.where(id: [ card_none, card_old, card_new ]).ordered_by_staleness.map(&:title)

      card_old.boost!

      assert_equal %w[ new old none ], Card.where(id: [ card_none, card_old, card_new ]).ordered_by_staleness.map(&:title)
    end
  end

  test "cards with no activity have a valid activity_score_order" do
    card = Card.create! collection: collections(:writebook), creator: users(:kevin)

    card.rescore

    assert card.activity_score.zero?
    assert_not card.activity_score_order.infinite?
  end
end
