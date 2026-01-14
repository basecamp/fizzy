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

  test "create via JSON returns no content" do
    assert_not cards(:layout).pinned_by?(users(:kevin))

    post card_pin_path(cards(:layout)), as: :json

    assert_response :no_content
    assert cards(:layout).pinned_by?(users(:kevin))
  end

  test "destroy via JSON returns no content" do
    assert cards(:shipping).pinned_by?(users(:kevin))

    delete card_pin_path(cards(:shipping)), as: :json

    assert_response :no_content
    assert_not cards(:shipping).pinned_by?(users(:kevin))
  end
end
