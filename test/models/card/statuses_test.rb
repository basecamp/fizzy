require "test_helper"

class Card::StatusesTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "cards start out in a `drafted` state" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Newly created card"

    assert card.drafted?
  end

  test "an event is created when a card is created in the published state" do
    assert_no_difference(-> { Event.count }) do
      boards(:writebook).cards.create! creator: users(:kevin), title: "Draft Card"
    end

    assert_difference(-> { Event.count } => +1) do
      @card = boards(:writebook).cards.create! creator: users(:kevin), title: "Published Card", status: :published
    end

    event = Event.last
    assert_equal @card, event.eventable
    assert_equal "card_published", event.action
  end

  test "an event is created when a card is published" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Published Card"
    assert_difference(-> { Event.count } => +1) do
      card.publish
    end

    event = Event.last
    assert_equal card, event.eventable
    assert_equal "card_published", event.action
  end

  test "created_at is updated when the card is published" do
    freeze_time

    card = travel_to 1.week.ago do
      boards(:writebook).cards.create! creator: users(:kevin), title: "Newly created card"
    end

    assert card.drafted?
    assert_equal 1.week.ago, card.created_at

    card.publish

    assert_equal Time.current, card.created_at
  end

  test "detect drafts that were just published" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Draft Card"
    assert card.drafted?
    assert_not card.was_just_published?

    card.publish

    assert card.was_just_published?
    assert_not Card.find(card.id).was_just_published?
  end

  test "detect cards that were created and published" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Published Card", status: :published
    assert card.was_just_published?

    assert_not Card.find(card.id).was_just_published?
  end
end
