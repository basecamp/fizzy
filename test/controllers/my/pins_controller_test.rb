require "test_helper"

class My::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get my_pins_url

    assert_response :success
    assert_select "div", text: /#{users(:kevin).pins.first.card.title}/
  end
end
