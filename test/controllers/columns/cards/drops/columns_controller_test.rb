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

  test "reorders within the same column without side effects" do
    board = boards(:writebook)
    column = columns(:writebook_in_progress)

    card = cards(:text)
    other = with_current_user(:kevin) do
      board.cards.create!(
        title: "Another card",
        creator: users(:kevin),
        status: "published",
        last_active_at: 2.days.ago,
        column: column
      )
    end

    other.update!(position: 1024)
    card.update!(position: 2048)

    assert_no_changes -> { card.reload.column_id } do
      assert_changes -> { card.reload.position }, to: 0 do
        assert_no_difference -> { card.events.count } do
          post columns_card_drops_column_path(card, column_id: column.id),
            params: { before_id: other.number },
            as: :turbo_stream
          assert_response :success
        end
      end
    end
  end
end
