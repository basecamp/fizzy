require "test_helper"

# The browser version gate (allow_browser) is for people's browsers. OAuth's
# machine endpoints answer whatever user agent a client's platform sends, an
# old browser's included, while consent stays behind the gate.
class OauthUserAgentsTest < ActionDispatch::IntegrationTest
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15"

  test "discovery answers an old browser's user agent" do
    untenanted { get "/.well-known/oauth-authorization-server", headers: old_browser }
    assert_response :success

    untenanted { get "/.well-known/oauth-protected-resource", headers: old_browser }
    assert_response :success
  end

  test "the token endpoint answers an old browser's user agent with an OAuth error" do
    untenanted { post oauth_token_path, params: { grant_type: "password" }, headers: old_browser }

    assert_response :bad_request
    assert_equal "unsupported_grant_type", response.parsed_body["error"]
  end

  test "the delegation exchange answers an old browser's user agent with an OAuth error" do
    untenanted do
      post oauth_token_path, headers: old_browser,
        params: { grant_type: Oauth::TokenDelegation::GRANT_TYPE, client_id: "unknown", client_secret: "wrong" }
    end

    assert_not_equal 406, response.status
    assert response.parsed_body["error"].present?
  end

  test "registration and revocation answer an old browser's user agent" do
    untenanted { post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/cb" ] }, as: :json, headers: old_browser }
    assert_response :created

    untenanted { post oauth_revocation_path, params: { token: "unknown" }, headers: old_browser }
    assert_response :ok
  end

  test "consent still turns an old browser away" do
    sign_in_as :david

    untenanted do
      get new_oauth_authorization_path, headers: old_browser, params: {
        client_id: oauth_clients(:mcp_client).client_id, redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256", scope: "read", state: "xyz"
      }
    end

    assert_response :not_acceptable
  end

  # Every OAuth controller but consent's is called by software, so a new one
  # has to choose: this fails until it's added to one list or the other.
  test "only consent enforces browser versions" do
    Rails.application.eager_load!
    people = [ Oauth::AuthorizationsController, Oauth::Authorizations::SwitchesController ]
    oauth = Oauth::BaseController.descendants

    assert_equal people.sort_by(&:name), oauth.select(&:browser_versions_enforced).sort_by(&:name)
  end

  private
    def old_browser
      { "User-Agent" => OLD_SAFARI }
    end
end
