require "test_helper"

class Card::StallableTest < ActiveSupport::TestCase
  include CardActivityTestHelper

  setup do
    Current.session = sessions(:david)
  end

  test "a card without activity spike is not stalled" do
    assert_not cards(:logo).stalled?
    assert_not_includes Card.stalled, cards(:logo)
  end

  test "a card with a recent activity spike is not stalled" do
    cards(:logo).create_activity_spike!

    assert_not cards(:logo).stalled?
    assert_not_includes Card.stalled, cards(:logo)
  end

  test "a card with an old activity spike is stalled" do
    cards(:logo).create_activity_spike!

    travel_to 3.months.from_now

    assert cards(:logo).stalled?
    assert_includes Card.stalled, cards(:logo)
  end

  test "a stalled card can be unstalled with a single comment" do
    cards(:logo).create_activity_spike!

    travel_to 3.months.from_now

    assert cards(:logo).stalled?
    assert_includes Card.stalled, cards(:logo)

    cards(:logo).comments.create!(body: "A new comment to unstall the card")

    assert_not cards(:logo).stalled?
    assert_not_includes Card.stalled, cards(:logo)

    # and stalls again after more time passes
    travel_to 3.months.from_now

    assert cards(:logo).stalled?
    assert_includes Card.stalled, cards(:logo)
  end

  test "a card with an old activity spike is not stalled after being postponed" do
    card = cards(:logo)
    card.create_activity_spike!

    travel_to 3.months.from_now

    assert card.stalled?
    assert_includes Card.stalled, card

    travel_to Time.now + card.board.entropy.auto_postpone_period + 1.day
    assert_operator card.entropy.auto_clean_at, :<=, Time.now

    Card.auto_postpone_all_due

    assert_not card.reload.stalled?
    assert_not_includes Card.stalled, card
  end

  # More fine-grained testing in Card::ActivitySpike::Detector
  test "detect activity spikes" do
    assert_not cards(:logo).stalled?
    multiple_people_comment_on(cards(:logo))

    travel_to 1.month.from_now
    assert cards(:logo).reload.stalled?
    assert_includes Card.stalled, cards(:logo)
  end

  test "don't detect activity spikes when updating attributes other than last_active_at" do
    assert_no_enqueued_jobs only: Card::ActivitySpike::DetectionJob do
      cards(:logo).update! created_at: 1.day.ago
    end
  end

  test "don't detect activity spikes when creating new cards" do
    assert_no_enqueued_jobs only: Card::ActivitySpike::DetectionJob do
      boards(:writebook).cards.create! title: "A new card", creator: users(:kevin)
    end
  end
end
