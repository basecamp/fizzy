require "test_helper"

class Cards::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { cards(:layout).pinned_by?(users(:kevin)) }, from: false, to: true do
      perform_enqueued_jobs do
        assert_turbo_stream_broadcasts([ users(:kevin), :pins_tray ], count: 1) do
          post card_pin_path(cards(:layout)), as: :turbo_stream
        end
      end
    end

    assert_response :success
  end

  test "create as JSON" do
    card = cards(:layout)

    assert_not card.pinned_by?(users(:kevin))

    post card_pin_path(card), as: :json

    assert_response :no_content
    assert card.reload.pinned_by?(users(:kevin))
  end

  test "destroy" do
    assert_changes -> { cards(:shipping).pinned_by?(users(:kevin)) }, from: true, to: false do
      perform_enqueued_jobs do
        assert_turbo_stream_broadcasts([ users(:kevin), :pins_tray ], count: 1) do
          delete card_pin_path(cards(:shipping)), as: :turbo_stream
        end
      end
    end

    assert_response :success
  end

  test "destroy as JSON" do
    card = cards(:shipping)

    assert card.pinned_by?(users(:kevin))

    delete card_pin_path(card), as: :json

    assert_response :no_content
    assert_not card.reload.pinned_by?(users(:kevin))
  end
end
