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

  test "reorders within stream without side effects" do
    board = boards(:writebook)
    card = cards(:buy_domain)
    other = with_current_user(:kevin) do
      board.cards.create!(
        title: "Another stream card",
        creator: users(:kevin),
        status: "published",
        last_active_at: 2.days.ago
      )
    end

    other.update!(position: 1024)
    card.update!(position: 2048)

    assert_no_changes -> { card.reload.triaged? } do
      assert_changes -> { card.reload.position }, to: 0 do
        assert_no_difference -> { card.events.count } do
          post columns_card_drops_stream_path(card),
            params: { before_id: other.number },
            as: :turbo_stream
          assert_response :success
        end
      end
    end
  end
end
