require "test_helper"

class Card::WatchableTest < ActiveSupport::TestCase
  setup do
    Watch.destroy_all
    Access.all.update!(involvement: :access_only)
  end

  test "watched_by?" do
    assert_not cards(:logo).watched_by?(users(:kevin))

    cards(:logo).watch_by users(:kevin)
    assert cards(:logo).watched_by?(users(:kevin))

    cards(:logo).unwatch_by users(:kevin)
    assert_not cards(:logo).watched_by?(users(:kevin))
  end

  test "watched_by? when notifications are set on the collection" do
    collections(:writebook).access_for(users(:kevin)).watching!
    assert cards(:text).watched_by?(users(:kevin))

    cards(:logo).unwatch_by users(:kevin)
    assert_not cards(:logo).watched_by?(users(:kevin))
  end

  test "cards are initially watched by their creator" do
    card = collections(:writebook).cards.create!(creator: users(:kevin))

    assert card.watched_by?(users(:kevin))
  end

  test "watchers_and_subscribers" do
    collections(:writebook).access_for(users(:kevin)).watching!
    collections(:writebook).access_for(users(:jz)).everything!

    cards(:logo).watch_by users(:kevin)
    cards(:logo).unwatch_by users(:jz)
    cards(:logo).watch_by users(:david)

    assert_equal [ users(:kevin), users(:david) ].sort, cards(:logo).watchers_and_subscribers.sort
  end
end
