require "test_helper"

class Users::LocalesControllerTest < ActionDispatch::IntegrationTest
  test "should get update" do
    get users_locales_update_url
    assert_response :success
  end
end
