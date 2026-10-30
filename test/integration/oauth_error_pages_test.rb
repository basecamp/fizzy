require "test_helper"

# The browser authorization flow answers a person with a page, in plain words,
# whatever refused the request; an app that asks for JSON, and every endpoint
# an app calls directly, keeps the OAuth answer it always had.
class OauthErrorPagesTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  METADATA_DOCUMENT_URL = "https://claude.ai/oauth/missing-client-metadata"

  setup do
    sign_in_as :david
  end

  test "an app not registered for the code grant is a page, not JSON" do
    get_authorization client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID

    assert_error_page "unauthorized_client", OauthHelper::OAUTH_ERROR_MESSAGES["unauthorized_client"]
    assert_select ".oauth-error__detail", text: /Client may not use the authorization code grant/

    get_authorization client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID, format: :json

    assert_oauth_json "unauthorized_client", :bad_request
  end

  test "a metadata document that can't be fetched is a page, and JSON when asked for" do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_dns_resolution("160.79.104.10")
    stub_request(:get, METADATA_DOCUMENT_URL).to_return(status: 404)

    get_authorization client_id: METADATA_DOCUMENT_URL, redirect_uri: "https://claude.ai/api/mcp/auth_callback"

    assert_error_page "invalid_client_metadata", OauthHelper::OAUTH_ERROR_MESSAGES["invalid_client_metadata"]

    get_authorization client_id: METADATA_DOCUMENT_URL, redirect_uri: "https://claude.ai/api/mcp/auth_callback", format: :json

    assert_oauth_json "invalid_client_metadata", :bad_request
  end

  test "a developer's description is shown beneath the plain words, never in their place" do
    get_authorization redirect_uri: "http://evil.example.com/steal"

    assert_error_page "invalid_request", "The app asked to send you back to an address it never registered with Fizzy."
    assert_select ".oauth-error__detail", text: /Invalid redirect_uri/
    assert_select "p.margin-none:not(.oauth-error__detail)", text: "Invalid redirect_uri", count: 0
  end

  test "an error with nothing particular to say reads as its code's sentence" do
    client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], dynamically_registered: true)

    {
      { code_challenge: nil } => [ "invalid_request", "code_challenge is required" ],
      { response_type: "token" } => [ "unsupported_response_type", "Only 'code' response_type is supported" ],
      { scope: "admin" } => [ "invalid_scope", "Requested scope is not allowed" ],
      { resource: "https://unknown.example.com/mcp" } => [ "invalid_target", "Unknown resource" ]
    }.each do |overrides, (error, description)|
      get_authorization client_id: client.client_id, redirect_uri: client.redirect_uris.first, **overrides

      assert_error_page error, OauthHelper::OAUTH_ERROR_MESSAGES.fetch(error)
      assert_select ".oauth-error__detail", text: /#{Regexp.escape(description)}/
    end
  end

  test "a browser and a wildcard Accept get the page; an app asking for JSON or anything else gets JSON" do
    get_authorization client_id: "nonexistent", headers: { "Accept" => "text/html,application/xhtml+xml,*/*;q=0.8" }
    assert_error_page "invalid_request", Oauth::AuthorizationsController::UNKNOWN_CLIENT_MESSAGE

    get_authorization client_id: "nonexistent", headers: { "Accept" => "*/*" }
    assert_error_page "invalid_request", Oauth::AuthorizationsController::UNKNOWN_CLIENT_MESSAGE

    get_authorization client_id: "nonexistent", headers: { "Accept" => "application/json" }
    assert_oauth_json "invalid_request", :bad_request

    get_authorization client_id: "nonexistent", headers: { "Accept" => "application/xml" }
    assert_oauth_json "invalid_request", :bad_request
  end

  test "a dark server shows a person the page for anything Fizzy doesn't have, and an app a bare 404" do
    with_oauth_availability acceptance: false do
      get_authorization
      assert_response :not_found
      assert_equal "text/html", response.media_type
      assert_equal File.read(Rails.public_path.join("404.html")), response.body
      assert_no_match "oauth", response.body.downcase

      get_authorization format: :json
      assert_response :not_found
      assert_empty response.body
    end
  end

  test "paused issuance tells a person so, and an app gets a bare 503" do
    with_oauth_availability acceptance: true, issuance: false do
      get_authorization
      assert_response :service_unavailable
      assert_select "h2", text: "Connecting apps is paused"

      get_authorization format: :json
      assert_response :service_unavailable
      assert_empty response.body
    end
  end

  test "endpoints apps call keep their bare statuses whatever they accept" do
    with_oauth_availability acceptance: true, issuance: false do
      untenanted { post oauth_token_path, params: { grant_type: "authorization_code", code: "x" } }
      assert_response :service_unavailable
      assert_empty response.body

      untenanted { post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/callback" ] }, headers: { "Accept" => "text/html" } }
      assert_response :service_unavailable
      assert_empty response.body
    end

    with_oauth_availability acceptance: false do
      untenanted { post oauth_token_path, params: { grant_type: "authorization_code", code: "x" }, headers: { "Accept" => "text/html" } }
      assert_response :not_found
      assert_empty response.body
    end
  end

  test "switching without a browser session is refused with an OAuth error body" do
    token = identities(:david).access_tokens.create!(permission: :write)
    reset!

    untenanted do
      post oauth_authorization_switch_path, params: authorization_params, as: :json, headers: { "Authorization" => "Bearer #{token.raw_token}" }
    end

    assert_oauth_json "access_denied", :forbidden
  end

  private
    def get_authorization(format: nil, headers: {}, **overrides)
      untenanted { get new_oauth_authorization_path(format: format), params: authorization_params(**overrides).compact, headers: headers }
    end

    def authorization_params(**overrides)
      {
        client_id: oauth_clients(:mcp_client).client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }.merge(overrides)
    end

    def assert_error_page(error, message)
      assert_response :bad_request
      assert_equal "text/html", response.media_type
      assert_select "h2", text: "Can't authorize this app"
      assert_select "p", text: message
      assert_select ".oauth-error__detail code", text: error
    end

    def assert_oauth_json(error, status)
      assert_response status
      assert_equal "application/json", response.media_type
      assert_equal error, response.parsed_body["error"]
    end
end
