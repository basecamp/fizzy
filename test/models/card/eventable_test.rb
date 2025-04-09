require "test_helper"

class Bubble::EventableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "new bubbles get the current time as the last activity time" do
    freeze_time

    bubble = buckets(:writebook).bubbles.create!(title: "Some card card", creator: users(:david))
    assert_equal Time.current, bubble.last_active_at
  end

  test "tracking events update the last activity time" do
    travel_to Time.current

    bubbles(:logo).pop!
    assert_equal Time.current, bubbles(:logo).last_active_at
  end
end
