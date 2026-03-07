require "test_helper"

class Public::Boards::Columns::ClosedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    boards(:writebook).publish
  end

  test "show" do
    get public_board_columns_closed_path(boards(:writebook).publication.key)
    assert_response :success
  end

  test "show excludes draft cards" do
    draft_card = cards(:buy_domain)
    draft_card.update!(status: :drafted)
    Current.set(user: users(:david)) { draft_card.close }

    get public_board_columns_closed_path(boards(:writebook).publication.key)
    assert_response :success
    assert_not_includes response.body, draft_card.title
  end
end
