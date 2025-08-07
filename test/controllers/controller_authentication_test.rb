require "test_helper"

class ControllerAuthenticationTest < ActionDispatch::IntegrationTest
  test "access without an account slug redirects to launchpad" do
    integration_session.default_url_options[:script_name] = "" # no tenant

    get cards_path

    assert_redirected_to Launchpad.login_url(product: true)
  end

  test "access with an account slug but no session redirects to launchpad" do
    get cards_path

    assert_redirected_to Launchpad.login_url(product: true, account: Account.sole)
  end

  test "local auth, access without an account slug redirects to launchpad" do
    integration_session.default_url_options[:script_name] = "" # no tenant

    with_local_auth do
      get cards_path
    end

    assert_redirected_to Launchpad.login_url(product: true)
  end

  test "local auth, access with an account slug but no session redirects to new session" do
    with_local_auth do
      get cards_path
    end

    assert_redirected_to new_session_path
  end

  test "access with an account slug and a session allows functional access" do
    sign_in_as :kevin

    get cards_path

    assert_response :success
  end
end
