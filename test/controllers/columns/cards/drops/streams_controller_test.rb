require "test_helper"

class Columns::Cards::Drops::StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:text)

    assert_changes -> { card.reload.triaged? }, from: true, to: false do
      post columns_card_drops_stream_path(card), as: :turbo_stream
      assert_response :success
    end
  end

  test "create keeps the board's filter on the maybe column" do
    post columns_card_drops_stream_path(cards(:text), tag_ids: [ tags(:mobile).id ]), as: :turbo_stream

    assert_response :success
    assert_includes response.body, ERB::Util.html_escape(cards(:text).title)
    assert_not_includes response.body, ERB::Util.html_escape(cards(:buy_domain).title)
    assert_includes response.body, "tag_ids"
  end
end
