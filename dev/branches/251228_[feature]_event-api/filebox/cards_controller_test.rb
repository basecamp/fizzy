require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  test "create as JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
           params: { card: { title: "My new card", description: "Big if true" } },
           as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal card_path(card, format: :json), @response.headers["Location"]

    assert_equal "My new card", card.title
    assert_equal "Big if true", card.description.to_plain_text
    # Add this to ensure the card is created in the 'maybe?' column.
    assert card.awaiting_triage?, "Card should be awaiting triage (in Maybe? column)"
  end
end
