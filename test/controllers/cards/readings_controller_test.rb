require "test_helper"

class Cards::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post card_reading_url(cards(:logo)), as: :turbo_stream
    end

    assert_response :success
  end
end
