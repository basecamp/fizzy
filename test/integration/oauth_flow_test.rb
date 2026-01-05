require "test_helper"

class OauthFlowTest < ActionDispatch::IntegrationTest
  # Authorization Endpoint

  test "authorization requires authentication" do
    client = oauth_clients(:mcp_client)

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: "test_challenge",
        code_challenge_method: "S256"
      }
    end

    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  test "authorization shows consent screen" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end

    assert_response :success
    assert_select "form[action$=?]", "/oauth/authorization"
    assert_match client.name, response.body
  end

  test "authorization rejects invalid client_id" do
    sign_in_as :david

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: "nonexistent",
        redirect_uri: "http://127.0.0.1/cb",
        response_type: "code",
        code_challenge: "test",
        code_challenge_method: "S256"
      }
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "authorization rejects mismatched redirect_uri" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://evil.com/steal",
        response_type: "code",
        code_challenge: "test",
        code_challenge_method: "S256",
        state: "abc"
      }
    end

    # Can't redirect to untrusted URI, so render HTML error page
    assert_response :bad_request
    assert_select "code", text: "invalid_request"
  end

  test "authorization requires PKCE" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        state: "abc"
      }
    end

    # Per RFC 6749, redirect to client with error in query params
    assert_response :redirect
    redirect_params = CGI.parse(URI.parse(response.location).query)
    assert_equal "invalid_request", redirect_params["error"].first
    assert_match "code_challenge", redirect_params["error_description"].first
  end

  test "authorization consent issues code" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)

    untenanted do
      post oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end

    assert_response :redirect
    redirect_uri = URI.parse(response.location)

    assert_equal "127.0.0.1", redirect_uri.host
    assert_equal "/callback", redirect_uri.path

    params = CGI.parse(redirect_uri.query)
    assert_not_nil params["code"]&.first
    assert_equal "xyz123", params["state"]&.first
  end


  # Token Endpoint

  test "token exchange with valid code and PKCE" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    client = oauth_clients(:mcp_client)
    identity = identities(:david)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identity.id,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read"

    assert_difference "Identity::AccessToken.count", 1 do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: code_verifier
        }, as: :json
      end
    end

    assert_response :success
    body = response.parsed_body

    assert_not_nil body["access_token"]
    assert_equal "Bearer", body["token_type"]
    assert_equal "read", body["scope"]

    token = Identity::AccessToken.find_by(token: body["access_token"])
    assert_equal client, token.oauth_client
    assert_equal identity, token.identity
    assert_equal "read", token.permission
  end

  test "token exchange rejects invalid code" do
    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: "invalid_code",
        redirect_uri: "http://127.0.0.1/cb",
        code_verifier: "verifier"
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "token exchange rejects wrong PKCE verifier" do
    code_verifier = "correct_verifier_here"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    client = oauth_clients(:mcp_client)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read"

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "http://127.0.0.1:8888/callback",
        code_verifier: "wrong_verifier"
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "token exchange rejects mismatched redirect_uri" do
    code_verifier = "verifier"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    client = oauth_clients(:mcp_client)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read"

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "http://127.0.0.1:9999/different",
        code_verifier: code_verifier
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "token exchange rejects expired code" do
    code_verifier = "verifier"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    client = oauth_clients(:mcp_client)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read"

    travel 65.seconds do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: code_verifier
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "token exchange rejects unsupported grant type" do
    untenanted do
      post oauth_token_path, params: { grant_type: "client_credentials" }, as: :json
    end

    assert_response :bad_request
    assert_equal "unsupported_grant_type", response.parsed_body["error"]
  end


  # Token Revocation (RFC 7009)

  test "revocation deletes access token" do
    token = identity_access_tokens(:davids_api_token)

    assert_difference "Identity::AccessToken.count", -1 do
      untenanted do
        post oauth_revocation_path, params: { token: token.token }, as: :json
      end
    end

    assert_response :success
  end

  test "revocation returns 200 for nonexistent token" do
    untenanted do
      post oauth_revocation_path, params: { token: "nonexistent_token" }, as: :json
    end
    assert_response :success
  end

  test "revocation returns 400 for blank token" do
    untenanted do
      post oauth_revocation_path, params: { token: "" }, as: :json
    end
    assert_response :bad_request
  end


  # Discovery Metadata (RFC 8414)

  test "authorization server metadata includes required fields" do
    untenanted do
      get "/.well-known/oauth-authorization-server"
    end

    assert_response :success
    body = response.parsed_body

    assert_equal "http://www.example.com/", body["issuer"]
    assert_match %r{/oauth/authorization/new$}, body["authorization_endpoint"]
    assert_match %r{/oauth/token$}, body["token_endpoint"]
    assert_match %r{/oauth/clients$}, body["registration_endpoint"]
    assert_includes body["response_types_supported"], "code"
    assert_includes body["code_challenge_methods_supported"], "S256"
  end

  test "protected resource metadata includes authorization server" do
    untenanted do
      get "/.well-known/oauth-protected-resource"
    end

    assert_response :success
    body = response.parsed_body

    assert_equal "http://www.example.com/", body["resource"]
    assert_includes body["authorization_servers"], "http://www.example.com/"
  end


  # Dynamic Client Registration (RFC 7591)

  test "DCR creates client with loopback redirect" do
    assert_difference "Oauth::Client.count", 1 do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Test MCP Client",
          redirect_uris: [ "http://127.0.0.1:8888/callback" ]
        }, as: :json
      end
    end

    assert_response :created
    body = response.parsed_body

    assert_not_nil body["client_id"]
    assert_equal "Test MCP Client", body["client_name"]
    assert_equal [ "http://127.0.0.1:8888/callback" ], body["redirect_uris"]
  end

  test "DCR rejects non-loopback redirect" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Evil Client",
          redirect_uris: [ "https://evil.com/steal" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "DCR requires redirect_uris" do
    untenanted do
      post oauth_clients_path, params: { client_name: "No Redirect" }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", response.parsed_body["error"]
  end


  # Full OAuth Flow

  test "complete authorization code flow" do
    sign_in_as :david
    client = oauth_clients(:mcp_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    # Step 1: Get consent screen
    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        scope: "read",
        state: "test_state"
      }
    end
    assert_response :success

    # Step 2: Grant consent
    untenanted do
      post oauth_authorization_path, params: {
        client_id: client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        scope: "read",
        state: "test_state"
      }
    end
    assert_response :redirect

    # Extract code from redirect
    redirect_uri = URI.parse(response.location)
    params = CGI.parse(redirect_uri.query)
    code = params["code"].first
    assert_not_nil code
    assert_equal "test_state", params["state"].first

    # Step 3: Exchange code for token
    assert_difference "Identity::AccessToken.count", 1 do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: code_verifier
        }, as: :json
      end
    end

    assert_response :success
    body = response.parsed_body
    assert_not_nil body["access_token"]
    assert_equal "Bearer", body["token_type"]
  end
end
