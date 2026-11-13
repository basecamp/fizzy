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

  test "a draft is saved with an empty description" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Draft Card"

    assert ActionText::RichText.exists?(record: card, name: "description")
    assert card.reload.description.blank?
  end

  test "a card created published gets no description it wasn't given" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Published Card", status: :published

    assert_not ActionText::RichText.exists?(record: card, name: "description")
  end

  # FIZZY-Z2: two autosaves of a new draft's first description, in flight together, each inserted
  # the rich text and the unique index refused the second. Each request loads the card before the
  # other's save lands; with the row saved with the draft, both saves are updates.
  test "two first saves of a draft's description in flight together both succeed" do
    draft = users(:kevin).draft_new_card_in(boards(:writebook))
    first, second = Card.find(draft.id), Card.find(draft.id)
    second.rich_text_description

    first.update!(description: "Typed first")
    second.update!(description: "Typed first, then more")

    assert_equal "Typed first, then more", draft.reload.description.to_plain_text
  end

  test "reopening a draft saved without a description row gives it one" do
    draft = cards(:unfinished_thoughts)
    assert_not ActionText::RichText.exists?(record: draft, name: "description")

    draft.creator.draft_new_card_in(draft.board)

    assert ActionText::RichText.exists?(record: draft, name: "description")
  end
end
