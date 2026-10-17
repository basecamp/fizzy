require "test_helper"

# Every authorization server response is uncacheable and sends no Referer,
# whether it succeeds, fails, or never reaches its action.
class OauthResponseHeadersTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  test "discovery documents" do
    untenanted { get "/.well-known/oauth-authorization-server" }
    assert_response :success
    assert_uncached_without_referrer

    untenanted { get "/.well-known/oauth-protected-resource" }
    assert_response :success
    assert_uncached_without_referrer
  end

  test "a dark server's answers" do
    with_oauth_availability acceptance: false do
      untenanted { get "/.well-known/oauth-authorization-server" }
      assert_response :not_found
      assert_uncached_without_referrer

      untenanted { post oauth_token_path, params: { grant_type: "authorization_code" }, as: :json }
      assert_response :not_found
      assert_uncached_without_referrer
    end
  end

  test "the sign-in redirect ahead of consent" do
    untenanted { get new_oauth_authorization_path, params: authorization_params }

    assert_response :redirect
    assert_match %r{/session/new}, response.location
    assert_uncached_without_referrer
  end

  test "the consent screen and its redirect to the client" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: authorization_params }
    assert_response :success
    assert_uncached_without_referrer

    untenanted { post oauth_authorization_path, params: authorization_params }
    assert_response :redirect
    assert_uncached_without_referrer
  end

  test "token, registration and revocation answers" do
    untenanted { post oauth_token_path, params: { grant_type: "password" }, as: :json }
    assert_response :bad_request
    assert_uncached_without_referrer

    untenanted { post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/cb" ] }, as: :json }
    assert_response :created
    assert_uncached_without_referrer

    untenanted { post oauth_revocation_path, params: { token: "unknown" } }
    assert_response :ok
    assert_uncached_without_referrer
  end

  private
    def authorization_params
      {
        client_id: oauth_clients(:mcp_client).client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz"
      }
    end

    def assert_uncached_without_referrer
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
    end
end
