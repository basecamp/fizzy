require "test_helper"

class OauthAuthorizationSwitchTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @client = oauth_clients(:mcp_client)
  end

  test "the consent screen offers to switch who is signed in" do
    untenanted { get new_oauth_authorization_path, params: authorization_params }

    assert_select "form[action=?] button", oauth_authorization_switch_path(script_name: nil), text: "Not you?"
  end

  test "switching signs out and saves the authorization request, rebuilt from its checked parameters" do
    assert_difference -> { identities(:david).sessions.count }, -1 do
      post_switch authorization_params.merge(return_to: "https://evil.example.com/", account_id: "123")
    end

    assert_redirected_to new_session_path(script_name: nil)
    assert_not cookies[:session_token].present?
    assert_equal expected_return_url, session[:return_to_after_authenticating]
  end

  test "switching requires a same-origin request" do
    with_forgery_protection do
      assert_no_difference -> { identities(:david).sessions.count } do
        post_switch authorization_params, headers: { "Sec-Fetch-Site" => "cross-site" }
      end
    end

    assert_response :unprocessable_entity
  end

  test "a redirect the client didn't register is refused, leaving the person signed in and nothing saved" do
    assert_no_difference -> { identities(:david).sessions.count } do
      post_switch authorization_params(redirect_uri: "https://evil.example.com/callback")
    end

    assert_response :bad_request
    assert cookies[:session_token].present?
    assert_nil session[:return_to_after_authenticating]
  end

  test "an unknown client is refused, leaving the person signed in" do
    assert_no_difference -> { identities(:david).sessions.count } do
      post_switch authorization_params(client_id: "forged")
    end

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
    assert_nil session[:return_to_after_authenticating]
  end

  test "a request too long to resume is refused before signing out" do
    assert_no_difference -> { identities(:david).sessions.count } do
      post_switch authorization_params(state: "x" * 2048)
    end

    assert_response :bad_request
    assert_select "p", text: /too long to pick up again/
    assert cookies[:session_token].present?
    assert_nil session[:return_to_after_authenticating]
  end

  test "whoever signs in next lands back on consent for the same request, and the saved request is used once" do
    post_switch authorization_params
    sign_in_as :kevin

    assert_equal expected_return_url, response.location
    assert_nil session[:return_to_after_authenticating]

    get response.location
    assert_response :success
    assert_select ".oauth-consent__identity strong", text: identities(:kevin).email_address

    sign_in_as :kevin
    assert_not_equal expected_return_url, response.location
  end

  private
    def authorization_params(**overrides)
      {
        client_id: @client.client_id,
        redirect_uri: @client.redirect_uris.first,
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }.merge(overrides)
    end

    def expected_return_url
      new_oauth_authorization_url(script_name: nil, **authorization_params)
    end

    def post_switch(params, **options)
      untenanted { post oauth_authorization_switch_path, params: params, **options }
    end

    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
