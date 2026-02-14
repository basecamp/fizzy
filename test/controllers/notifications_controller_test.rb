require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index as JSON" do
    get notifications_path, as: :json

    assert_response :success
    assert_kind_of Array, @response.parsed_body
    assert @response.parsed_body.any? { |n| n["id"] == notifications(:logo_assignment_kevin).id }
  end

  test "index as JSON includes notification attributes" do
    get notifications_path, as: :json

    notification = @response.parsed_body.find { |n| n["id"] == notifications(:logo_assignment_kevin).id }

    assert_not_nil notification["created_at"]
    assert_not_nil notification["card"]
    assert_not_nil notification["creator"]
    assert_not_nil notification["unread_count"]
    assert_not_nil notification.dig("creator", "avatar_url")
    assert_not_nil notification.dig("card", "number")
    assert_not_nil notification.dig("card", "board_name")
    assert_not_nil notification.dig("card", "column")

    card = notifications(:logo_assignment_kevin).card
    assert_equal card.closed?, notification.dig("card", "closed")
    assert_equal card.postponed?, notification.dig("card", "postponed")
  end
end
