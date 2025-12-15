require "test_helper"

class Card::EventableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "new cards default last_active_at to created_at" do
    freeze_time

    card = boards(:writebook).cards.create!(title: "Some card", creator: users(:david))
    assert_equal card.created_at, card.last_active_at
  end

  test "new cards with custom created_at default last_active_at to that time" do
    custom_time = 1.week.ago.change(usec: 0)

    card = boards(:writebook).cards.create!(title: "Backdated card", creator: users(:david), created_at: custom_time)
    assert_equal custom_time, card.created_at
    assert_equal custom_time, card.last_active_at
  end

  test "new cards preserve explicit last_active_at" do
    created_time = 2.weeks.ago.change(usec: 0)
    last_active_time = 1.week.ago.change(usec: 0)

    card = boards(:writebook).cards.create! \
      title: "Card with explicit timestamps",
      creator: users(:david),
      created_at: created_time,
      last_active_at: last_active_time

    assert_equal created_time, card.created_at
    assert_equal last_active_time, card.last_active_at
  end

  test "publishing a card does not overwrite last_active_at" do
    created_time = 2.weeks.ago.change(usec: 0)
    last_active_time = 1.week.ago.change(usec: 0)

    card = boards(:writebook).cards.create! \
      title: "Published card",
      creator: users(:david),
      status: :published,
      created_at: created_time,
      last_active_at: last_active_time

    assert_equal last_active_time, card.last_active_at
  end

  test "tracking events update the last activity time" do
    travel_to Time.current

    cards(:logo).close
    assert_equal Time.current, cards(:logo).last_active_at
  end
end
