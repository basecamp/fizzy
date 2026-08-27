require "test_helper"

class Events::DaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get events_days_path
    assert_response :success
  end

  test "index with a valid day param" do
    get events_days_path(day: "2026-08-23")
    assert_response :success
  end

  test "index returns not found for an unparseable day param" do
    get events_days_path(day: "garbage")
    assert_response :not_found
  end

  test "index returns not found for an out-of-range day param" do
    get events_days_path(day: "2026-99-99")
    assert_response :not_found
  end

  test "index returns not found for a non-string day param" do
    get events_days_path(day: [ "garbage" ])
    assert_response :not_found
  end
end
