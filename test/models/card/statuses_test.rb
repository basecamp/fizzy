require "test_helper"

class Bubble::StatusesTest < ActiveSupport::TestCase
  test "bubbles start out in a `creating` state" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "Newly created bubble"

    assert bubble.creating?
    assert_not_includes Bubble.published_or_drafted_by(users(:kevin)), bubble
    assert_not_includes Bubble.published_or_drafted_by(users(:jz)), bubble
  end

  test "bubbles are only visible to the creator when drafted" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "Drafted Bubble"
    bubble.drafted!

    assert_includes Bubble.published_or_drafted_by(users(:kevin)), bubble
    assert_not_includes Bubble.published_or_drafted_by(users(:jz)), bubble
  end

  test "bubbles are visible to everyone when published" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin), title: "Published Bubble"
    bubble.published!

    assert_includes Bubble.published_or_drafted_by(users(:kevin)), bubble
    assert_includes Bubble.published_or_drafted_by(users(:jz)), bubble
  end

  test "can_recover_abandoned_creation?" do
    bubble = buckets(:writebook).bubbles.create! creator: users(:kevin)
    unsaved_bubble = buckets(:writebook).bubbles.new creator: users(:kevin)

    assert_not unsaved_bubble.can_recover_abandoned_creation?

    bubble.update!(title: "Something worth keeping")
    assert unsaved_bubble.can_recover_abandoned_creation?
  end

  test "recover_abandoned_creation" do
    bubble_edited = buckets(:writebook).bubbles.create! creator: users(:kevin)
    bubble_edited.update!(title: "Something worth keeping")

    bubble_not_edited = buckets(:writebook).bubbles.create! creator: users(:kevin)

    assert bubble_not_edited.can_recover_abandoned_creation?

    assert_equal bubble_edited, bubble_not_edited.recover_abandoned_creation

    assert_raises(ActiveRecord::RecordNotFound) { bubble_not_edited.reload }
  end

  test "remove_abandoned_creations" do
    bubble_old = buckets(:writebook).bubbles.create! creator: users(:kevin), updated_at: 2.days.ago
    bubble_recent = buckets(:writebook).bubbles.create! creator: users(:kevin)

    assert_equal 2, Bubble.creating.count

    Bubble.remove_abandoned_creations

    assert_equal [ bubble_recent ], Bubble.creating
  end
end
