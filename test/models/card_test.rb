require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "capturing messages" do
    assert_difference "cards(:logo).messages.comments.count", +1 do
      cards(:logo).capture Comment.new(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).messages.comments.last.messageable.body.to_plain_text.chomp
  end

  test "boosting" do
    assert_changes -> { cards(:logo).activity_score } do
      assert_difference -> { cards(:logo).boosts_count }, +1 do
        cards(:logo).boost!(cards(:logo).boosts_count+ 1)
      end
    end
  end

  test "assignment states" do
    assert cards(:logo).assigned_to?(users(:kevin))
    assert_not cards(:logo).assigned_to?(users(:david))
  end

  test "assignment toggling" do
    assert cards(:logo).assigned_to?(users(:kevin))

    assert_difference({ "cards(:logo).assignees.count" => -1, "Event.count" => +1 }) do
      cards(:logo).toggle_assignment users(:kevin)
    end
    assert_not cards(:logo).assigned_to?(users(:kevin))
    assert_equal "unassigned", Event.last.action
    assert_equal [ users(:kevin) ], Event.last.assignees

    assert_difference %w[ cards(:logo).assignees.count Event.count ], +1 do
      cards(:logo).toggle_assignment users(:kevin)
    end
    assert cards(:logo).assigned_to?(users(:kevin))
    assert_equal "assigned", Event.last.action
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

    assert_difference %w[ cards(:logo).taggings.count accounts("37s").tags.count ], +1 do
      cards(:logo).toggle_tag_with "prioritized"
    end
    assert_equal "prioritized", cards(:logo).taggings.last.tag.title
  end

  test "searchable by title" do
    card = collections(:writebook).cards.create! title: "Insufficient haggis", creator: users(:kevin)

    assert_includes Card.search("haggis"), card
  end

  test "ordering by comments" do
    assert_equal cards(:logo, :layout, :shipping, :text), Card.ordered_by_comments
  end

  test "ordering by boosts" do
    cards(:layout).update! boosts_count: 1_000
    assert_equal cards(:layout, :logo, :shipping, :text), Card.ordered_by_boosts
  end

  test "closed" do
    assert_equal [ cards(:shipping) ], Card.closed
  end

  test "active" do
    assert_equal cards(:logo, :layout, :text), Card.active
  end

  test "unassigned" do
    assert_equal cards(:shipping, :text), Card.unassigned
  end

  test "assigned to" do
    assert_equal cards(:logo, :layout), Card.assigned_to(users(:jz))
  end

  test "assigned by" do
    assert_equal cards(:layout, :logo), Card.assigned_by(users(:david))
  end

  test "in collection" do
    new_collection = accounts("37s").collections.create! name: "New Collection", creator: users(:david)
    assert_equal cards(:logo, :shipping, :layout, :text), Card.in_collection(collections(:writebook))
    assert_empty Card.in_collection(new_collection)
  end

  test "tagged with" do
    assert_equal cards(:layout, :text), Card.tagged_with(tags(:mobile))
  end

  test "mentioning" do
    card = collections(:writebook).cards.create! title: "Insufficient haggis", creator: users(:kevin)
    cards(:logo).capture Comment.new(body: "I hate haggis")
    cards(:text).capture Comment.new(body: "I love haggis")

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

  test "cache key gracefully handles a nil collection" do
    card = cards(:logo)
    card.update_column :collection_id, Collection.last.id + 1

    assert_nothing_raised { card.reload.cache_key }
  end
end
