require "test_helper"

class Sessions::SingleSignOnsControllerTest < ActionDispatch::IntegrationTest
  DESKTOP_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  NATIVE_USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
    "(KHTML, like Gecko) Hotwire Native iOS/1.0 bridge-components: [title]"

  setup do
    enable_single_sign_on provider_name: "Acme SSO"
    stub_single_sign_on_provider
  end

  teardown do
    disable_single_sign_on
  end

  test "not found when single sign-on is not configured" do
    disable_single_sign_on

    untenanted do
      get new_session_single_sign_on_path
      assert_response :not_found

      post session_single_sign_on_path
      assert_response :not_found
    end
  end

  test "new renders a form that submits outside Turbo" do
    untenanted do
      get new_session_single_sign_on_path
    end

    assert_response :success
    assert_select "meta[name='turbo-visit-control'][content='reload']", visible: false
    assert_select "form[action='/session/single_sign_on'][data-turbo='false'][data-controller~='auto-submit']" do
      assert_select "button > span", text: "Continue with Acme SSO"
    end
  end

  test "new tells native app users to open a browser" do
    cookies[:x_user_agent] = NATIVE_USER_AGENT

    untenanted do
      get new_session_single_sign_on_path, headers: { "User-Agent" => DESKTOP_USER_AGENT }
    end

    assert_response :success
    assert_select "h1", text: "Open Fizzy in your browser"
    assert_select "form[action='/session/single_sign_on']", count: 0
  end

  test "create redirects to the provider" do
    untenanted do
      post session_single_sign_on_path
    end

    assert_response :redirect
    assert response.location.start_with?("#{SINGLE_SIGN_ON_AUTHORIZATION_ENDPOINT}?")

    parameters = single_sign_on_authorization_parameters
    assert_equal "http://www.example.com/session/single_sign_on/callback", parameters["redirect_uri"]
    assert_equal SINGLE_SIGN_ON_CLIENT_ID, parameters["client_id"]
    assert_equal "S256", parameters["code_challenge_method"]
    assert parameters["state"].present?
    assert parameters["nonce"].present?
  end

  test "create with a long return address" do
    untenanted do
      post session_single_sign_on_path, params: { return_to: "http://www.example.com/1/boards?#{"a" * 3.kilobytes}" }
    end

    assert_response :redirect
    assert response.location.start_with?("#{SINGLE_SIGN_ON_AUTHORIZATION_ENDPOINT}?")
  end

  test "create is rate limited" do
    Rails.cache.stubs(:increment).returns(301)

    untenanted do
      post session_single_sign_on_path
    end

    assert_response :too_many_requests
    assert_select "p", text: /too many sign-in attempts/
    assert_select "button", text: "Try Acme SSO again"
  end

  test "create when the provider cannot be reached" do
    stub_request(:get, "#{SINGLE_SIGN_ON_ISSUER}/.well-known/openid-configuration").to_timeout

    untenanted do
      post session_single_sign_on_path
    end

    assert_response :unauthorized
    assert_select "p", text: "Fizzy cannot connect to Acme SSO. Try again later."
  end
end
