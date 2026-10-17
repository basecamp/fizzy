require "test_helper"

class OauthAvailabilityTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  # Discovery follows acceptance

  test "a dark server publishes no discovery documents" do
    with_oauth_availability acceptance: false do
      untenanted { get "/.well-known/oauth-authorization-server" }
      assert_response :not_found

      untenanted { get "/.well-known/oauth-protected-resource" }
      assert_response :not_found
    end
  end

  test "a pilot client does not make a dark server discoverable" do
    with_oauth_availability acceptance: false, pilot_client_ids: [ oauth_clients(:mcp_client).client_id ] do
      untenanted { get "/.well-known/oauth-authorization-server", params: { client_id: oauth_clients(:mcp_client).client_id } }
      assert_response :not_found
    end
  end

  test "pausing issuance keeps discovery up" do
    with_oauth_availability acceptance: true, issuance: false do
      untenanted { get "/.well-known/oauth-authorization-server" }
      assert_response :success

      untenanted { get "/.well-known/oauth-protected-resource" }
      assert_response :success
    end
  end

  # Issuance

  test "a dark server registers no clients" do
    with_oauth_availability acceptance: false do
      assert_no_difference "Oauth::Client.count" do
        untenanted { post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/callback" ] }, as: :json }
      end
    end

    assert_response :not_found
  end

  test "naming a pilot client does not open registration on a dark server" do
    with_oauth_availability acceptance: false, issuance: false, pilot_client_ids: [ oauth_clients(:mcp_client).client_id ] do
      assert_no_difference "Oauth::Client.count" do
        untenanted { post oauth_clients_path, params: { client_id: oauth_clients(:mcp_client).client_id, redirect_uris: [ "http://127.0.0.1:9999/callback" ] }, as: :json }
      end
    end

    assert_response :not_found
  end

  test "pausing issuance refuses registration with 503" do
    with_oauth_availability acceptance: true, issuance: false do
      assert_no_difference "Oauth::Client.count" do
        untenanted { post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/callback" ] }, as: :json }
      end
    end

    assert_response :service_unavailable
  end

  test "a dark server does not ask a signed-out user to sign in to authorize" do
    with_oauth_availability acceptance: false do
      untenanted { get new_oauth_authorization_path, params: authorization_params }
    end

    assert_response :not_found
  end

  test "a dark server shows no consent screen" do
    sign_in_as :david

    with_oauth_availability acceptance: false do
      untenanted { get new_oauth_authorization_path, params: authorization_params }
    end

    assert_response :not_found
  end

  test "a dark server issues no code on approval" do
    sign_in_as :david

    with_oauth_availability acceptance: false do
      untenanted { post oauth_authorization_path, params: authorization_params }
    end

    assert_response :not_found
  end

  test "pausing issuance refuses authorization with 503" do
    sign_in_as :david

    with_oauth_availability acceptance: true, issuance: false do
      untenanted { get new_oauth_authorization_path, params: authorization_params }
      assert_response :service_unavailable

      untenanted { post oauth_authorization_path, params: authorization_params }
      assert_response :service_unavailable
    end
  end

  test "a denial still reaches the client while dark" do
    sign_in_as :david

    with_oauth_availability acceptance: false, issuance: false do
      untenanted { post oauth_authorization_path, params: authorization_params.merge(error: "access_denied") }
    end

    assert_response :redirect
    assert_match %r{\Ahttp://127\.0\.0\.1:8888/callback\?error=access_denied}, response.location
  end

  test "a dark server mints no tokens" do
    with_oauth_availability acceptance: false do
      assert_no_difference "Identity::AccessToken.count" do
        untenanted { post oauth_token_path, params: token_params, as: :json }
      end
    end

    assert_response :not_found
  end

  test "pausing issuance refuses the token endpoint with 503" do
    with_oauth_availability acceptance: true, issuance: false do
      assert_no_difference "Identity::AccessToken.count" do
        untenanted { post oauth_token_path, params: token_params, as: :json }
      end
    end

    assert_response :service_unavailable
  end

  test "a pilot client completes the flow against a dark server" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)

    with_oauth_availability acceptance: false, issuance: false, pilot_client_ids: [ client.client_id ] do
      untenanted { get new_oauth_authorization_path, params: authorization_params }
      assert_response :success

      untenanted { post oauth_authorization_path, params: authorization_params }
      assert_response :redirect

      untenanted { post oauth_token_path, params: token_params, as: :json }
      assert_response :success

      get user_path(users(:david)), env: bearer(response.parsed_body["access_token"]), as: :json
      assert_response :success
    end
  end

  test "another client is still refused while a pilot runs" do
    with_oauth_availability acceptance: false, pilot_client_ids: [ oauth_clients(:trusted_client).client_id ] do
      untenanted { post oauth_token_path, params: token_params, as: :json }
    end

    assert_response :not_found
  end

  # Acceptance

  test "OAuth bearer tokens are refused while acceptance is off" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :read)

    with_oauth_availability acceptance: false do
      get user_path(users(:david)), env: bearer(token.token), as: :json
    end

    assert_response :unauthorized
  end

  test "personal access tokens still work while OAuth is dark" do
    with_oauth_availability acceptance: false do
      get user_path(users(:jason)), env: bearer(identity_access_tokens(:jasons_api_token).token), as: :json
    end

    assert_response :success
  end

  test "pausing issuance keeps existing OAuth tokens working" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :read)

    with_oauth_availability acceptance: true, issuance: false do
      get user_path(users(:david)), env: bearer(token.token), as: :json
    end

    assert_response :success
  end

  # Management is never gated

  test "revocation works while dark" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :read)

    with_oauth_availability acceptance: false, issuance: false do
      assert_difference "Identity::AccessToken.count", -1 do
        untenanted { post oauth_revocation_path, params: { token: token.token } }
      end
    end

    assert_response :success
  end

  test "Connected Apps lists and disconnects while dark" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)
    identities(:david).access_tokens.create!(oauth_client: client, permission: :read)

    with_oauth_availability acceptance: false, issuance: false do
      get my_connected_apps_path
      assert_response :success
      assert_match client.name, response.body

      assert_difference "Identity::AccessToken.count", -1 do
        delete my_connected_app_path(client)
      end
      assert_redirected_to my_connected_apps_path
    end
  end

  private
    def authorization_params
      {
        client_id: oauth_clients(:mcp_client).client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false),
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end

    def token_params
      {
        grant_type: "authorization_code",
        client_id: oauth_clients(:mcp_client).client_id,
        code: Oauth::AuthorizationCode.generate(
          client_id: oauth_clients(:mcp_client).client_id,
          identity_id: identities(:david).id,
          code_challenge: authorization_params[:code_challenge],
          redirect_uri: "http://127.0.0.1:8888/callback",
          scope: "read"),
        redirect_uri: "http://127.0.0.1:8888/callback",
        code_verifier: CODE_VERIFIER
      }
    end

    def bearer(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end
end
