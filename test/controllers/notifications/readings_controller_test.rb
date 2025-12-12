require "test_helper"

class Notifications::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post notification_reading_path(notifications(:logo_published_kevin), format: :turbo_stream)
      assert_response :success
    end
  end

  test "destroy" do
    notification = notifications(:logo_published_kevin)
    notification.read # Mark as read first

    assert_changes -> { notification.reload.read? }, from: true, to: false do
      delete notification_reading_path(notification, format: :turbo_stream)
      assert_response :success
    end
  end

  test "create as JSON" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post notification_reading_path(notifications(:logo_published_kevin)), as: :json
      assert_response :no_content
    end
  end

  test "destroy as JSON" do
    notification = notifications(:logo_published_kevin)
    notification.read

    assert_changes -> { notification.reload.read? }, from: true, to: false do
      delete notification_reading_path(notification), as: :json
      assert_response :no_content
    end
  end
end
