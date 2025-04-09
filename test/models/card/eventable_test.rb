require "test_helper"

class Card::EventableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "new cards get the current time as the last activity time" do
    freeze_time

    card = collections(:writebook).cards.create!(title: "Some card card", creator: users(:david))
    assert_equal Time.current, card.last_active_at
  end

  test "tracking events update the last activity time" do
    travel_to Time.current

    cards(:logo).close
    assert_equal Time.current, cards(:logo).last_active_at
  end
end
