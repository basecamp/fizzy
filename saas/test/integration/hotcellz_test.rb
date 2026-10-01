require "test_helper"

class HotcellzTest < ActionDispatch::IntegrationTest
  HOTCELLZ = "/hotcellz"
  HOTCELLZ_TEST = "/hotcellz/test"

  test "answers without a session" do
    get HOTCELLZ

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "FAIL", response.body
  end

  test "tells an unauthenticated caller nothing but whether the cell answered" do
    get HOTCELLZ

    assert_no_match(/hotcell|running|queued|uptime|HOTCELL_ROOT/i, response.body)
  end

  test "sends a caller without a session to sign in before the test action" do
    get HOTCELLZ_TEST

    assert_response :redirect
  end

  test "refuses the test action to a signed-in identity that is not staff" do
    sign_in_as :mike

    untenanted { get HOTCELLZ_TEST }

    assert_response :forbidden
  end

  test "reports every check to staff, the work-socket round trips included" do
    sign_in_as :david

    untenanted { get HOTCELLZ_TEST }

    assert_equal "application/json", response.media_type
    assert_equal %w[ describe metrics echo reopen ], response.parsed_body.dig("cells", Fizzy::Saas::Cell::NAME).keys
  end
end
