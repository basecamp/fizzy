require "test_helper"

class Cards::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { cards(:layout).pinned_by?(users(:kevin)) }, from: false, to: true do
      perform_enqueued_jobs do
        assert_turbo_stream_broadcasts([ users(:kevin), :pins ], count: 1) do
          post card_pin_path(cards(:layout))
        end
      end
    end

    assert_redirected_to card_pin_path(cards(:layout))
  end

  test "destroy" do
    assert_changes -> { cards(:shipping).pinned_by?(users(:kevin)) }, from: true, to: false do
      perform_enqueued_jobs do
        assert_turbo_stream_broadcasts([ users(:kevin), :pins ], count: 1) do
          delete card_pin_path(cards(:shipping))
        end
      end
    end

    assert_redirected_to card_pin_path(cards(:shipping))
  end
end
