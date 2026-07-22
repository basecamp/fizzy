require "test_helper"

class Card::BubbleUpTest < ActiveSupport::TestCase
  test "due to resurface scope" do
    bubbling_card = cards(:postponed_idea)
    non_bubbling_card = cards(:logo)

    assert_not_includes Card::BubbleUp.due_to_resurface, bubbling_card.bubble_up

    bubbling_card.bubble_up.update(resurface_at: Time.now - 1.minute)

    assert_includes Card::BubbleUp.due_to_resurface, bubbling_card.bubble_up
    assert_not_includes Card::BubbleUp.due_to_resurface, non_bubbling_card.bubble_up
  end

  test "resurface all due" do
    bubbling_card = cards(:postponed_idea)
    bubbling_card.bubble_up.update(resurface_at: Time.now - 1.minute)

    assert_difference -> { Card.awaiting_triage.count } do
      Card::BubbleUp.resurface_all_due
    end

    assert_not bubbling_card.reload.postponed?
    assert bubbling_card.reload.awaiting_triage?
  end
end
