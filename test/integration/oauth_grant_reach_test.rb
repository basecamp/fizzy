require "test_helper"

# An OAuth grant acts for an app on the user's data. It may not manage the
# user's credentials or consent to apps: anything it minted there would outlive
# disconnecting the app, and anything it removed would be someone else's.
class OauthGrantReachTest < ActionDispatch::IntegrationTest
  setup do
    @grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)
    @bearer = { "HTTP_AUTHORIZATION" => "Bearer #{@grant.token}" }
  end

  test "an OAuth grant can't consent to an app" do
    untenanted do
      post oauth_authorization_path, params: { client_id: oauth_clients(:trusted_client).client_id, redirect_uri: oauth_clients(:trusted_client).redirect_uris.first,
        response_type: "code", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256", scope: "read write", state: "s" },
        env: @bearer, as: :json
    end

    assert_response :forbidden
  end

  test "an OAuth grant can't disconnect an app" do
    other = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:trusted_client))

    delete my_connected_app_path(oauth_clients(:trusted_client)), env: @bearer, as: :json

    assert_response :forbidden
    assert Identity::AccessToken.exists?(other.id)
  end

  test "an OAuth grant can't register a passkey" do
    post my_passkeys_path, params: { passkey: { client_data_json: "{}" } }, env: @bearer, as: :json
    assert_response :forbidden
  end

  test "an OAuth grant can't mint a transfer link" do
    post transfer_token_path, env: @bearer, as: :json

    assert_response :forbidden
  end

  test "a personal access token still manages personal access tokens" do
    pat = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }

    get my_access_tokens_path, env: pat, as: :json

    assert_response :success
  end
end
