require "test_helper"

class Card::StatusesTest < ActiveSupport::TestCase
  test "cards start out in a `creating` state" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "Newly created card"

    assert card.creating?
    assert_not_includes Card.published_or_drafted_by(users(:kevin)), card
    assert_not_includes Card.published_or_drafted_by(users(:jz)), card
  end

  test "cards are only visible to the creator when drafted" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "Drafted Card"
    card.drafted!

    assert_includes Card.published_or_drafted_by(users(:kevin)), card
    assert_not_includes Card.published_or_drafted_by(users(:jz)), card
  end

  test "cards are visible to everyone when published" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "Published Card"
    card.published!

    assert_includes Card.published_or_drafted_by(users(:kevin)), card
    assert_includes Card.published_or_drafted_by(users(:jz)), card
  end

  test "can_recover_abandoned_creation?" do
    card = collections(:writebook).cards.create! creator: users(:kevin)
    unsaved_card = collections(:writebook).cards.new creator: users(:kevin)

    assert_not unsaved_card.can_recover_abandoned_creation?

    card.update!(title: "Something worth keeping")
    assert unsaved_card.can_recover_abandoned_creation?
  end

  test "recover_abandoned_creation" do
    card_edited = collections(:writebook).cards.create! creator: users(:kevin)
    card_edited.update!(title: "Something worth keeping")

    card_not_edited = collections(:writebook).cards.create! creator: users(:kevin)

    assert card_not_edited.can_recover_abandoned_creation?

    assert_equal card_edited, card_not_edited.recover_abandoned_creation

    assert_raises(ActiveRecord::RecordNotFound) { card_not_edited.reload }
  end

  test "remove_abandoned_creations" do
    card_old = collections(:writebook).cards.create! creator: users(:kevin), updated_at: 2.days.ago
    card_recent = collections(:writebook).cards.create! creator: users(:kevin)

    assert_equal 2, Card.creating.count

    Card.remove_abandoned_creations

    assert_equal [ card_recent ], Card.creating
  end
end
