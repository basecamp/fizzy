require "test_helper"

class OauthDcrRedirectsTest < ActionDispatch::IntegrationTest
  # VS Code registers its vscode.dev callbacks beside loopback, all in one set,
  # which a host allowlist refused whole.
  VSCODE_CALLBACKS = %w[ https://vscode.dev/redirect https://insiders.vscode.dev/redirect http://127.0.0.1/ http://127.0.0.1:33418/ ]

  test "registration accepts https on any plain host we don't run" do
    register(*VSCODE_CALLBACKS)
    assert_response :created
    assert_equal VSCODE_CALLBACKS, Oauth::Client.find_by!(client_id: response.parsed_body["client_id"]).redirect_uris

    %w[ https://claude.ai/api/mcp/auth_callback https://acme-be.glean.com/oauth/callback https://connector.example.com:8443/callback ].each do |uri|
      register uri
      assert_response :created, uri
    end
  end

  test "registration refuses plain http, fragments and userinfo, naming what it accepts" do
    %w[ http://connector.example.com/callback https://connector.example.com/callback#frag https://user@connector.example.com/callback
        https://%65vil.example/callback ].each do |uri|
      assert_no_difference "Oauth::Client.count" do
        register uri
      end

      assert_response :bad_request, uri
      assert_equal "invalid_redirect_uri", response.parsed_body["error"], uri
      assert_match "https redirects on a plain host this server doesn't run", response.parsed_body["error_description"], uri
    end
  end

  test "one refused callback refuses the whole registration" do
    assert_no_difference "Oauth::Client.count" do
      register(*VSCODE_CALLBACKS, "http://elsewhere.example/callback")
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  # Consent names a self-registered app by where its access returns, so a
  # callback on a host we run would read as ours: this install's own host,
  # as configured (example.com in tests) and as served (www.example.com, with
  # or without BASE_URL), and 37signals' domains, in any case or subdomain.
  test "registration refuses https callbacks on hosts we run" do
    %w[
      https://example.com/callback
      https://EXAMPLE.com/callback
      https://app.fizzy.do/callback
      https://FIZZY.do/callback
      https://app.fizzy-staging.com/callback
      https://3.basecamp.com/callback
      https://basecamp.com/callback
      https://launchpad.37signals.com/callback
      https://app.hey.com/callback
      https://www.example.com/callback
    ].each do |uri|
      assert_no_difference "Oauth::Client.count" do
        register uri
      end

      assert_response :bad_request, uri
      assert_equal "invalid_redirect_uri", response.parsed_body["error"], uri
    end
  end

  test "registration accepts the cursor and claude app schemes and no others" do
    register "cursor://anysphere.cursor-mcp/oauth/callback", "claude://claude.ai/mcp-auth-callback/sdk"
    assert_response :created

    %w[ com.example.app://callback vscode://callback cursor:callback ].each do |uri|
      register uri
      assert_response :bad_request, uri
      assert_equal "invalid_redirect_uri", response.parsed_body["error"], uri
    end
  end

  test "an app-scheme client gets its code at its app redirect" do
    sign_in_as :david
    register "cursor://anysphere.cursor-mcp/oauth/callback"
    client = Oauth::Client.find_by!(client_id: response.parsed_body["client_id"])

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "cursor://anysphere.cursor-mcp/oauth/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read"
      }
    end
    assert_response :success
    assert_includes response.headers["Content-Security-Policy"], "cursor:"
    assert_select "h1", text: "Connect this app to Fizzy?"

    untenanted do
      post oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "cursor://anysphere.cursor-mcp/oauth/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end

    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal "cursor", location.scheme
    assert_equal "anysphere.cursor-mcp", location.host
    assert Rack::Utils.parse_query(location.query)["code"].present?
  end

  test "an app scheme naming a loopback host gets no pre-consent redirect" do
    sign_in_as :david
    register "cursor://localhost/callback"
    assert_response :created
    client = Oauth::Client.find_by!(client_id: response.parsed_body["client_id"])

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "cursor://localhost/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "plain",
        scope: "read"
      }
    end

    assert_response :bad_request
    assert_nil response.location
  end

  test "a self-registered https client gets its code at its callback" do
    sign_in_as :david
    register "https://connector.example.com/callback"
    client = Oauth::Client.find_by!(client_id: response.parsed_body["client_id"])

    untenanted do
      post oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "https://connector.example.com/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end

    assert_response :redirect
    assert_match %r{\Ahttps://connector\.example\.com/callback\?}, response.location
    assert Rack::Utils.parse_query(URI.parse(response.location).query)["code"].present?
  end

  # Errors found before consent aren't bounced to a host nobody vetted
  # (RFC 9700 §4.11.2), now that any host can be registered.
  test "a self-registered https client's error is shown here, not redirected" do
    sign_in_as :david
    register "https://connector.example.com/callback"
    client = Oauth::Client.find_by!(client_id: response.parsed_body["client_id"])

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "https://connector.example.com/callback",
        response_type: "token",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read"
      }
    end

    assert_response :bad_request
    assert_nil response.location
  end

  private
    def register(*redirect_uris)
      untenanted do
        post oauth_clients_path, params: { client_name: "Connector", redirect_uris: redirect_uris }, as: :json
      end
    end
end
