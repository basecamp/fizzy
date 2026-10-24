require "test_helper"

class OauthDcrRedirectAllowlistTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  test "registration accepts https only on an allowed host" do
    with_dcr_allowed_https_hosts "claude.ai", "chatgpt.com" do
      register "https://claude.ai/api/mcp/auth_callback"
      assert_response :created

      register "https://connector.example.com/callback"
      assert_response :bad_request
      assert_equal "invalid_redirect_uri", response.parsed_body["error"]
      assert_match "https redirects on claude.ai, chatgpt.com", response.parsed_body["error_description"]
    end
  end

  test "one unallowed host refuses the whole registration" do
    with_dcr_allowed_https_hosts "claude.ai" do
      assert_no_difference "Oauth::Client.count" do
        register "http://127.0.0.1:8888/callback", "https://claude.ai/api/mcp/auth_callback", "https://elsewhere.example/callback"
      end

      assert_response :bad_request
      assert_equal "invalid_redirect_uri", response.parsed_body["error"]
    end
  end

  test "with no allowed hosts, registration takes loopback and app schemes but no https" do
    with_dcr_allowed_https_hosts do
      register "https://claude.ai/api/mcp/auth_callback"
      assert_response :bad_request
      assert_match "no https redirects on this server", response.parsed_body["error_description"]

      register "http://127.0.0.1:8888/callback", "http://[::1]:8888/callback", "http://localhost:8888/callback"
      assert_response :created
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
    assert_select "strong", text: "cursor://anysphere.cursor-mcp"

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

  test "a client registered before its host left the allowlist still authorizes" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], dynamically_registered: true)

    with_dcr_allowed_https_hosts do
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
    end

    assert_response :redirect
    assert_match %r{\Ahttps://connector\.example\.com/callback\?}, response.location
    assert Rack::Utils.parse_query(URI.parse(response.location).query)["code"].present?
  end

  private
    def register(*redirect_uris)
      untenanted do
        post oauth_clients_path, params: { client_name: "Connector", redirect_uris: redirect_uris }, as: :json
      end
    end
end
