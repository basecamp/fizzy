require "test_helper"

class Notifications::BulkReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create marks all notifications as read" do
    assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: false, to: true do
        post bulk_reading_path
      end
    end
  end

  test "create redirects to notifications path when not from tray" do
    post bulk_reading_path
    assert_redirected_to notifications_path
  end

  test "create returns ok when from tray" do
    post bulk_reading_path, params: { from_tray: true }
    assert_response :ok
  end

  test "create as JSON" do
    assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: false, to: true do
        post bulk_reading_path, as: :json
      end
    end

    assert_response :no_content
  end
end
