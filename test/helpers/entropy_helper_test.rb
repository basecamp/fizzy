require "test_helper"

class EntropyHelperTest < ActionView::TestCase
  test "stalled_bubble_options_for returns nil when card has no activity spike" do
    assert_nil stalled_bubble_options_for(cards(:logo))
  end

  test "stalled_bubble_options_for returns options when card has activity spike" do
    card = cards(:logo)
    card.create_activity_spike!

    options = stalled_bubble_options_for(card)
    assert_not_nil options
    assert_equal card.last_activity_spike_at.iso8601, options[:lastActivitySpikeAt]
  end

  test "stalled_bubble_options_for includes updatedAt for client-side staleness check" do
    card = cards(:logo)
    card.create_activity_spike!

    travel_to 3.months.from_now

    # Touch the card to simulate step completion
    card.touch

    options = stalled_bubble_options_for(card)
    # The helper must include updatedAt so JS can check if card was recently updated
    assert_equal card.updated_at.iso8601, options[:updatedAt]
  end
end
