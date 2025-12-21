require "test_helper"

class Columns::Cards::Drops::NotNowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_changes -> { card.reload.postponed? }, from: false, to: true do
      post columns_card_drops_not_now_path(card), as: :turbo_stream
      assert_response :success
    end
  end

  test "reorders within not now without side effects" do
    card = cards(:layout)
    other = cards(:shipping)

    with_current_user(:kevin) do
      card.postpone
      other.postpone
    end

    other.update!(position: 1024)
    card.update!(position: 2048)

    assert_no_changes -> { card.reload.postponed? } do
      assert_changes -> { card.reload.position }, to: 0 do
        assert_no_difference -> { card.events.count } do
          post columns_card_drops_not_now_path(card),
            params: { before_id: other.number },
            as: :turbo_stream
          assert_response :success
        end
      end
    end
  end
end
