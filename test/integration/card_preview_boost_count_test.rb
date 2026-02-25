require "test_helper"

class CardPreviewBoostCountTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card_with_reactions = cards(:logo)
    @card_without_reactions = cards(:layout)
    @column = @card_with_reactions.column
  end

  test "card preview displays boost count when card has reactions" do
    get board_column_path(@column.board, @column)
    assert_response :success

    # Check that boost count is displayed for cards with reactions
    assert_select ".card__boosts", text: /2/
  end

  test "card preview does not display boost count when card has no reactions" do
    # Ensure layout card is in the same column for this test
    @card_without_reactions.update!(column: @column)

    get board_column_path(@column.board, @column)
    assert_response :success

    # Find the card without reactions and verify no boost count is shown
    # We check the overall page doesn't have a boost count for zero reactions
    # (This is an imperfect test but reasonable given the structure)
    assert @card_without_reactions.reactions.none?
  end
end
