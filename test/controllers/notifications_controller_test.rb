require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index as JSON" do
    get notifications_path, as: :json

    assert_response :success
    assert_kind_of Array, @response.parsed_body
    assert @response.parsed_body.any? { |n| n["id"] == notifications(:logo_published_kevin).id }
  end

  test "index as JSON includes notification attributes" do
    get notifications_path, as: :json

    notification = @response.parsed_body.find { |n| n["id"] == notifications(:logo_published_kevin).id }

    assert_not_nil notification["title"]
    assert_not_nil notification["body"]
    assert_not_nil notification["created_at"]
    assert_not_nil notification["card"]
    assert_not_nil notification["creator"]
  end
end
