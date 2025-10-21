require "test_helper"

class Sessions::LoginMenusControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      identify_as :kevin

      get session_login_menu_url

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      sign_in_as :kevin

      assert cookies[:session_token].present?
    end
  end
end
