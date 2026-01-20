require "test_helper"

class BubbleUpHelperTest < ActionView::TestCase
  test "bubble_up_options_for returns nil when card has no bubble up" do
    assert_nil bubble_up_options_for(cards(:logo))
  end

  test "bubble_up_options_for returns options when card has bubble up" do
    card = cards(:postponed_idea)

    options = bubble_up_options_for(card)
    assert_not_nil options
    assert options[:isPostponed]
  end

  test "slot_too_soon returns true when it's 17:00 or later for latertoday slot" do
    travel_to Time.zone.parse("2026-01-26 17:00:00") do
      assert_not slot_too_soon("tomorrow")
    end

    travel_to Time.zone.parse("2026-01-26 16:00:00") do
      assert_not slot_too_soon("latertoday")
    end

    travel_to Time.zone.parse("2026-01-26 17:00:00") do
      assert slot_too_soon("latertoday")
    end
  end
end
