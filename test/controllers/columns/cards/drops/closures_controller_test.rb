require "test_helper"

class Columns::Cards::Drops::ClosuresControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_changes -> { card.reload.closed? }, from: false, to: true do
      post columns_card_drops_closure_path(card), as: :turbo_stream
      assert_response :success
    end
  end

  test "reorders within done without side effects" do
    card = cards(:logo)
    other = cards(:layout)

    with_current_user(:kevin) do
      card.close
      other.close
    end

    other.update!(position: 1024)
    card.update!(position: 2048)

    assert_no_changes -> { card.reload.closed? } do
      assert_changes -> { card.reload.position }, to: 0 do
        assert_no_difference -> { card.events.count } do
          post columns_card_drops_closure_path(card),
            params: { before_id: other.number },
            as: :turbo_stream
          assert_response :success
        end
      end
    end
  end
end
