require "test_helper"

class Columns::Cards::Drops::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    column = columns(:writebook_in_progress)

    assert_changes -> { card.reload.column }, to: column do
      post columns_card_drops_column_path(card, column_id: column.id), as: :turbo_stream
      assert_response :success
    end
  end

  test "create keeps the board's filter on the column" do
    post columns_card_drops_column_path(cards(:buy_domain), column_id: columns(:writebook_triage).id, tag_ids: [ tags(:mobile).id ]), as: :turbo_stream

    assert_response :success
    assert_select "##{dom_id(columns(:writebook_triage))} .cards__expander-count", text: "1"
  end
end
