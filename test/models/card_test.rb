require "test_helper"

class BubbleTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "capturing messages" do
    assert_difference "bubbles(:logo).messages.comments.count", +1 do
      bubbles(:logo).capture Comment.new(body: "Agreed.")
    end

    assert_equal "Agreed.", bubbles(:logo).messages.comments.last.messageable.body.to_plain_text.chomp
  end

  test "boosting" do
    assert_changes -> { bubbles(:logo).activity_score } do
      assert_difference -> { bubbles(:logo).boosts_count }, +1 do
        bubbles(:logo).boost!(bubbles(:logo).boosts_count+ 1)
      end
    end
  end

  test "assignment states" do
    assert bubbles(:logo).assigned_to?(users(:kevin))
    assert_not bubbles(:logo).assigned_to?(users(:david))
  end

  test "assignment toggling" do
    assert bubbles(:logo).assigned_to?(users(:kevin))

    assert_difference({ "bubbles(:logo).assignees.count" => -1, "Event.count" => +1 }) do
      bubbles(:logo).toggle_assignment users(:kevin)
    end
    assert_not bubbles(:logo).assigned_to?(users(:kevin))
    assert_equal "unassigned", Event.last.action
    assert_equal [ users(:kevin) ], Event.last.assignees

    assert_difference %w[ bubbles(:logo).assignees.count Event.count ], +1 do
      bubbles(:logo).toggle_assignment users(:kevin)
    end
    assert bubbles(:logo).assigned_to?(users(:kevin))
    assert_equal "assigned", Event.last.action
    assert_equal [ users(:kevin) ], Event.last.assignees
  end

  test "tagged states" do
    assert bubbles(:logo).tagged_with?(tags(:web))
    assert_not bubbles(:logo).tagged_with?(tags(:mobile))
  end

  test "tag toggling" do
    assert bubbles(:logo).tagged_with?(tags(:web))

    assert_difference "bubbles(:logo).taggings.count", -1 do
      bubbles(:logo).toggle_tag_with tags(:web).title
    end
    assert_not bubbles(:logo).tagged_with?(tags(:web))

    assert_difference "bubbles(:logo).taggings.count", +1 do
      bubbles(:logo).toggle_tag_with tags(:web).title
    end
    assert bubbles(:logo).tagged_with?(tags(:web))

    assert_difference %w[ bubbles(:logo).taggings.count accounts("37s").tags.count ], +1 do
      bubbles(:logo).toggle_tag_with "prioritized"
    end
    assert_equal "prioritized", bubbles(:logo).taggings.last.tag.title
  end

  test "searchable by title" do
    bubble = buckets(:writebook).bubbles.create! title: "Insufficient haggis", creator: users(:kevin)

    assert_includes Bubble.search("haggis"), bubble
  end

  test "ordering by comments" do
    assert_equal bubbles(:logo, :layout, :shipping, :text), Bubble.ordered_by_comments
  end

  test "ordering by boosts" do
    bubbles(:layout).update! boosts_count: 1_000
    assert_equal bubbles(:layout, :logo, :shipping, :text), Bubble.ordered_by_boosts
  end

  test "popped" do
    assert_equal [ bubbles(:shipping) ], Bubble.popped
  end

  test "active" do
    assert_equal bubbles(:logo, :layout, :text), Bubble.active
  end

  test "unassigned" do
    assert_equal bubbles(:shipping, :text), Bubble.unassigned
  end

  test "assigned to" do
    assert_equal bubbles(:logo, :layout), Bubble.assigned_to(users(:jz))
  end

  test "assigned by" do
    assert_equal bubbles(:layout, :logo), Bubble.assigned_by(users(:david))
  end

  test "in bucket" do
    new_bucket = accounts("37s").buckets.create! name: "New Bucket", creator: users(:david)
    assert_equal bubbles(:logo, :shipping, :layout, :text), Bubble.in_bucket(buckets(:writebook))
    assert_empty Bubble.in_bucket(new_bucket)
  end

  test "tagged with" do
    assert_equal bubbles(:layout, :text), Bubble.tagged_with(tags(:mobile))
  end

  test "mentioning" do
    bubble = buckets(:writebook).bubbles.create! title: "Insufficient haggis", creator: users(:kevin)
    bubbles(:logo).capture Comment.new(body: "I hate haggis")
    bubbles(:text).capture Comment.new(body: "I love haggis")

    assert_equal [ bubble, bubbles(:logo), bubbles(:text) ].sort, Bubble.mentioning("haggis").sort
  end

  test "cache key includes the bucket name" do
    bubble = bubbles(:logo)
    cache_v1_key = bubble.cache_key

    bubble.bucket.touch
    assert_equal cache_v1_key, bubble.reload.cache_key, "general bucket touching should not affect the bubble's cache key"

    bubble.bucket.update! name: "Good ideas"
    assert_not_equal cache_v1_key, bubble.reload.cache_key, "changing the name of the bucket should invalidate the cache"
  end

  test "cache key includes the tenant name" do
    bubble = bubbles(:logo)

    assert_includes bubble.cache_key, ApplicationRecord.current_tenant, "cache key must always include the tenant"
  end

  test "cache key gracefully handles a nil bucket" do
    bubble = bubbles(:logo)
    bubble.update_column :bucket_id, Bucket.last.id + 1

    assert_nothing_raised { bubble.reload.cache_key }
  end
end
