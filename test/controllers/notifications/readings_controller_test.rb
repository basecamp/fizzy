require "test_helper"

class Notifications::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post read_notification_path(notifications(:logo_published_kevin), format: :turbo_stream)
      assert_response :success
    end
  end

  test "destroy" do
    notification = notifications(:logo_published_kevin)
    notification.read # Mark as read first

    assert_changes -> { notification.reload.read? }, from: true, to: false do
      delete read_notification_path(notification, format: :turbo_stream)
      assert_response :success
    end
  end

  test "create all" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: false, to: true do
        post read_all_notifications_path
        assert_redirected_to notifications_path
      end
    end
  end
end
