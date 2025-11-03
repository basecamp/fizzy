require "test_helper"

class Card::StatusesTest < ActiveSupport::TestCase
  test "cards start out in a `drafted` state" do
    card = collections(:writebook).cards.create! creator: users(:kevin), title: "Newly created card"

    assert card.drafted?
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

  test "an event is created when a card is created in the published state" do
    Current.session = sessions(:david)

    assert_no_difference(-> { Event.count }) do
      collections(:writebook).cards.create! creator: users(:kevin), title: "Draft Card"
    end

    assert_difference(-> { Event.count } => +1) do
      @card = collections(:writebook).cards.create! creator: users(:kevin), title: "Published Card", status: :published
    end

    assert_equal @card, Event.last.eventable
    assert_equal "card_published", Event.last.action
  end

  test "an event is created when a card is published" do
    Current.session = sessions(:david)

    card = collections(:writebook).cards.create! creator: users(:kevin), title: "Published Card"
    assert_difference(-> { Event.count } => +1) do
      card.publish
    end

    assert_equal card, Event.last.eventable
    assert_equal "card_published", Event.last.action
  end
end
