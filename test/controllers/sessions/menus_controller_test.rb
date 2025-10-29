require "test_helper"

class Sessions::MenusControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      sign_in_as :kevin

      get session_menu_url

      assert_response :success
    end
  end
end
