require "test_helper"

class ControllerAuthenticationTest < ActionDispatch::IntegrationTest
  test "access without an account slug redirects to new session" do
    integration_session.default_url_options[:script_name] = "" # no tenant

    get cards_path

    assert_response :success
    assert_dom "p", text: "You don't have any existing Fizzy accounts."
  end

  test "access with an account slug but no session redirects to new session" do
    get cards_path

    assert_redirected_to new_session_path
  end

  test "access with an account slug and a session allows functional access" do
    sign_in_as :kevin

    get cards_path

    assert_response :success
  end
end
