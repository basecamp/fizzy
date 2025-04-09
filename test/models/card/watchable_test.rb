require "test_helper"

class Bubble::WatchableTest < ActiveSupport::TestCase
  setup do
    Watch.destroy_all
    Access.all.update!(involvement: :access_only)
  end

  test "watched_by?" do
    assert_not bubbles(:logo).watched_by?(users(:kevin))

    bubbles(:logo).watch_by users(:kevin)
    assert bubbles(:logo).watched_by?(users(:kevin))

    bubbles(:logo).unwatch_by users(:kevin)
    assert_not bubbles(:logo).watched_by?(users(:kevin))
  end

  test "watched_by? when notifications are set on the bucket" do
    buckets(:writebook).access_for(users(:kevin)).watching!
    assert bubbles(:text).watched_by?(users(:kevin))

    bubbles(:logo).unwatch_by users(:kevin)
    assert_not bubbles(:logo).watched_by?(users(:kevin))
  end

  test "bubbles are initially watched by their creator" do
    bubble = buckets(:writebook).bubbles.create!(creator: users(:kevin))

    assert bubble.watched_by?(users(:kevin))
  end

  test "watchers_and_subscribers" do
    buckets(:writebook).access_for(users(:kevin)).watching!
    buckets(:writebook).access_for(users(:jz)).everything!

    bubbles(:logo).watch_by users(:kevin)
    bubbles(:logo).unwatch_by users(:jz)
    bubbles(:logo).watch_by users(:david)

    assert_equal [ users(:kevin), users(:david) ].sort, bubbles(:logo).watchers_and_subscribers.sort
  end
end
