require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "destroy" do
    sign_in_as :kevin

    delete session_path

    assert_redirected_to Launchpad.login_url(account: Account.sole)
    assert_not cookies[:session_token].present?
  end

  test "local auth, destroy" do
    sign_in_as :kevin

    with_local_auth do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?
  end

  test "new" do
    get new_session_path

    assert_response :forbidden
  end

  test "local auth, new" do
    with_local_auth do
      get new_session_path
    end

    assert_response :success
  end

  test "create" do
    post session_path, params: { email_address: "david@37signals.com", password: "secret123456" }

    assert_response :forbidden
  end

  test "local auth, create with valid credentials" do
    with_local_auth do
      post session_path, params: { email_address: "david@37signals.com", password: "secret123456" }
    end

    assert_redirected_to root_path
    assert cookies[:session_token].present?
  end

  test "local auth, create with invalid credentials" do
    with_local_auth do
      post session_path, params: { email_address: "david@37signals.com", password: "wrong" }
    end

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?
  end
end
