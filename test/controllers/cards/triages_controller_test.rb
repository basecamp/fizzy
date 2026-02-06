require "test_helper"

class Cards::TriagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    original_column = card.column
    column = columns(:writebook_in_progress)

    assert_changes -> { card.reload.column }, from: original_column, to: column do
      post card_triage_path(card, column_id: column.id)
      assert_redirected_to card
    end
  end

  test "destroy" do
    card = cards(:shipping)

    assert_changes -> { card.reload.column }, to: nil do
      delete card_triage_path(card), as: :turbo_stream
      assert_redirected_to card
    end
  end

  test "create as JSON" do
    card = cards(:logo)
    column = columns(:writebook_in_progress)

    post card_triage_path(card, column_id: column.id), as: :json

    assert_response :no_content
    assert_equal column, card.reload.column
  end

  test "destroy as JSON" do
    card = cards(:shipping)

    assert card.column.present?

    delete card_triage_path(card), as: :json

    assert_response :no_content
    assert_nil card.reload.column
  end
end
