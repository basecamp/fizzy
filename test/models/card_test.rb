require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "capturing messages" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      cards(:logo).comments.create!(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).comments.last.body.to_plain_text.chomp
  end

  test "assignment states" do
    assert cards(:logo).assigned_to?(users(:kevin))
    assert_not cards(:logo).assigned_to?(users(:david))
  end

  test "assignment toggling" do
    assert cards(:logo).assigned_to?(users(:kevin))

    assert_difference({ -> { cards(:logo).assignees.count } => -1, -> { Event.count } => +1 }) do
      cards(:logo).toggle_assignment users(:kevin)
    end
    assert_not cards(:logo).assigned_to?(users(:kevin))
    assert_equal "card_unassigned", Event.last.action
    assert_equal [ users(:kevin) ], Event.last.assignees

    assert_difference %w[ cards(:logo).assignees.count Event.count ], +1 do
      cards(:logo).toggle_assignment users(:kevin)
    end
    assert cards(:logo).assigned_to?(users(:kevin))
    assert_equal "card_assigned", Event.last.action
    assert_equal [ users(:kevin) ], Event.last.assignees
  end

  test "tagged states" do
    assert cards(:logo).tagged_with?(tags(:web))
    assert_not cards(:logo).tagged_with?(tags(:mobile))
  end

  test "tag toggling" do
    assert cards(:logo).tagged_with?(tags(:web))

    assert_difference "cards(:logo).taggings.count", -1 do
      cards(:logo).toggle_tag_with tags(:web).title
    end
    assert_not cards(:logo).tagged_with?(tags(:web))

    assert_difference "cards(:logo).taggings.count", +1 do
      cards(:logo).toggle_tag_with tags(:web).title
    end
    assert cards(:logo).tagged_with?(tags(:web))

    assert_difference %w[ cards(:logo).taggings.count Tag.count ], +1 do
      cards(:logo).toggle_tag_with "prioritized"
    end
    assert_equal "prioritized", cards(:logo).taggings.last.tag.title
  end

  test "searchable by title" do
    card = collections(:writebook).cards.create! title: "Insufficient haggis", creator: users(:kevin)

    assert_includes Card.search("haggis"), card
  end

  test "closed" do
    assert_equal [ cards(:shipping) ], Card.closed
  end

  test "open" do
    assert_equal cards(:logo, :layout, :text, :buy_domain), Card.open
  end

  test "card_unassigned" do
    assert_equal cards(:shipping, :text, :buy_domain), Card.unassigned
  end

  test "assigned to" do
    assert_equal cards(:logo, :layout), Card.assigned_to(users(:jz))
  end

  test "assigned by" do
    assert_equal cards(:layout, :logo), Card.assigned_by(users(:david))
  end

  test "in collection" do
    new_collection = Collection.create! name: "New Collection", creator: users(:david)
    assert_equal cards(:logo, :shipping, :layout, :text, :buy_domain), Card.where(collection: collections(:writebook))
    assert_empty Card.where(collection: new_collection)
  end

  test "tagged with" do
    assert_equal cards(:layout, :text), Card.tagged_with(tags(:mobile))
  end

  test "mentioning" do
    card = collections(:writebook).cards.create! title: "Insufficient haggis", creator: users(:kevin)
    cards(:logo).comments.create!(body: "I hate haggis")
    cards(:text).comments.create!(body: "I love haggis")

    assert_equal [ card, cards(:logo), cards(:text) ].sort, Card.mentioning("haggis").sort
  end

  test "cache key includes the collection name" do
    card = cards(:logo)
    cache_v1_key = card.cache_key

    card.collection.touch
    assert_equal cache_v1_key, card.reload.cache_key, "general collection touching should not affect the card's cache key"

    card.collection.update! name: "Good ideas"
    assert_not_equal cache_v1_key, card.reload.cache_key, "changing the name of the collection should invalidate the cache"
  end

  test "cache key includes the tenant name" do
    card = cards(:logo)

    assert_includes card.cache_key, ApplicationRecord.current_tenant, "cache key must always include the tenant"
  end

  test "for published cards, it should set the default title 'Untitiled' when not provided" do
    card = collections(:writebook).cards.create!
    assert_nil card.title

    card.publish
    assert_equal "Untitled", card.reload.title
  end

  test "send back to triage when moved to a new collection" do
    cards(:logo).update! column: columns(:writebook_in_progress)

    assert_changes -> { cards(:logo).reload.triaged? }, from: true, to: false do
      cards(:logo).update! collection: collections(:private)
    end
  end

  test "grants access to assignees when moved to a new collection" do
    card = cards(:logo)
    assignee = users(:david)
    card.toggle_assignment(assignee)

    collection = collections(:private)
    assert_not_includes collection.users, assignee

    card.update!(collection: collection)
    assert_includes collection.users.reload, assignee
  end

  test "move cards to a different collection" do
    card = cards(:logo)
    old_collection = collections(:writebook)
    new_collection = collections(:private)

    assert_equal old_collection, card.collection

    assert card.events.where(collection: old_collection).exists?

    card.move_to(new_collection)

    assert_equal new_collection, card.reload.collection

    events_in_old_collection = card.events.where(collection: old_collection)
    events_in_new_collection = card.events.where(collection: new_collection)

    assert_empty events_in_old_collection
    assert events_in_new_collection.exists?

    collection_changed_event = events_in_new_collection.find { |event| event.action == "card_collection_changed" }
    assert collection_changed_event
  end
end
