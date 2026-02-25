require "test_helper"

class My::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get my_pins_path

    assert_response :success
    assert_select "div", text: /#{users(:kevin).pins.first.card.title}/
  end

  test "index as JSON" do
    expected_ids = users(:kevin).pins.ordered.pluck(:card_id)

    get my_pins_path(format: :json)

    assert_response :success
    assert_equal expected_ids.count, @response.parsed_body.count
    assert_equal expected_ids, @response.parsed_body.map { |card| card["id"] }
  end
end
