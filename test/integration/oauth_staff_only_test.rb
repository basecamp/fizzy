require "test_helper"

# While OAuth is staff only (Oauth::Availability), only 37signals staff can
# connect an app or use what they connected, whichever client asks.
class OauthStaffOnlyTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  test "staff see the consent screen and connect" do
    with_oauth_availability staff_only: true do
      sign_in_as :david
      get_consent_screen
      assert_response :success
      assert_select "form[action$=?]", "/oauth/authorization"

      post_consent
      assert_response :redirect
      assert_match %r{\Ahttp://127\.0\.0\.1:8888/callback\?code=}, response.location
    end
  end

  test "anyone else is told OAuth is staff only, and gets no code" do
    with_oauth_availability staff_only: true do
      sign_in_as :jz
      get_consent_screen
      assert_response :forbidden
      assert_match "Only 37signals staff can connect apps", response.body

      post_consent
      assert_response :forbidden
      assert_nil response.location
    end
  end

  test "anyone else can still decline" do
    with_oauth_availability staff_only: true do
      sign_in_as :jz
      post_consent error: "access_denied"

      assert_response :redirect
      assert_match "error=access_denied", response.location
    end
  end

  test "everyone connects when it's off" do
    sign_in_as :jz
    get_consent_screen

    assert_response :success
  end

  test "a code issued to someone no longer staff mints nothing" do
    code = authorization_code_for(identities(:david))
    identities(:david).update!(staff: false)

    with_oauth_availability staff_only: true do
      redeem code
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "a staff code redeems" do
    with_oauth_availability staff_only: true do
      redeem authorization_code_for(identities(:david))
    end

    assert_response :success
  end

  test "a grant stops working, and refreshing, once its owner isn't staff" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    with_oauth_availability staff_only: true do
      get user_path(users(:david)), env: { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }, as: :json
      assert_response :success

      identities(:david).update!(staff: false)

      get user_path(users(:david)), env: { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }, as: :json
      assert_response :unauthorized
      assert_match 'error="invalid_token"', response.headers["WWW-Authenticate"]

      refresh grant
      assert_response :bad_request
      assert_equal "invalid_grant", response.parsed_body["error"]
    end

    assert grant.reload.persisted?, "a refused refresh leaves the grant to its owner to revoke"
  end

  test "a staff grant refreshes" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    with_oauth_availability staff_only: true do
      refresh grant
    end

    assert_response :success
  end

  test "personal access tokens work for anyone" do
    identities(:david).update!(staff: false)

    with_oauth_availability staff_only: true do
      get user_path(users(:david)), env: { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }, as: :json
    end

    assert_response :success
  end

  private
    def get_consent_screen(**params)
      untenanted { get new_oauth_authorization_path, params: consent_params(**params) }
    end

    def post_consent(**params)
      untenanted { post oauth_authorization_path, params: consent_params(**params) }
    end

    def consent_params(**overrides)
      {
        client_id: oauth_clients(:mcp_client).client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }.merge(overrides)
    end

    def code_challenge
      Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false)
    end

    def authorization_code_for(identity)
      Oauth::AuthorizationCode.generate \
        client_id: oauth_clients(:mcp_client).client_id,
        identity_id: identity.id,
        code_challenge: code_challenge,
        redirect_uri: "http://127.0.0.1:8888/callback",
        scope: "read"
    end

    def redeem(code)
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          client_id: oauth_clients(:mcp_client).client_id,
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: CODE_VERIFIER
        }, as: :json
      end
    end

    def refresh(grant)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: grant.raw_refresh_token, client_id: oauth_clients(:mcp_client).client_id }, as: :json
      end
    end
end
