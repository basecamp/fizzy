require "test_helper"

class Users::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show self" do
    get user_events_path(users(:kevin))
    assert_in_body "What have you been up to?"
  end

  test "show other" do
    get user_events_path(users(:david))
    assert_in_body "What has David been up to?"
  end

  test "show returns not found for an unparseable day param" do
    get user_events_path(users(:kevin), day: "garbage")
    assert_response :not_found
  end

  test "show returns not found for an out-of-range day param" do
    get user_events_path(users(:kevin), day: "2026-99-99")
    assert_response :not_found
  end

  test "show returns not found for a non-string day param" do
    get user_events_path(users(:kevin), day: [ "garbage" ])
    assert_response :not_found
  end
end
