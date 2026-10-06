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

  test "authorization errors for a self-registered https client render here instead of redirecting" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], dynamically_registered: true)

    get_consent_screen client: client, code_challenge: nil

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
  end

  test "no pre-consent error redirects to a self-registered https host" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], dynamically_registered: true)

    {
      { scope: "admin" } => "invalid_scope",
      { state: nil } => "invalid_request",
      { response_type: "token" } => "unsupported_response_type",
      { code_challenge_method: "plain" } => "invalid_request"
    }.each do |overrides, error|
      get_consent_screen client: client, **overrides

      assert_response :bad_request, "#{overrides} should not redirect"
      assert_nil response.location
      assert_select "code", text: error
    end
  end

  test "pre-consent errors still redirect to an operator-provisioned https client" do
    sign_in_as :david

    get_consent_screen client: oauth_clients(:trusted_client), scope: "admin"

    assert_response :redirect
    assert_match %r{\Ahttps://app\.example\.com/oauth/callback\?}, response.location
    assert_equal "invalid_scope", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
  end

  test "authorization errors for a self-registered loopback client still redirect" do
    sign_in_as :david

    get_consent_screen code_challenge: nil

    assert_response :redirect
    assert_equal "invalid_request", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
  end

  test "consent names a self-registered redirect's port when it isn't the default" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com:8443/callback ], dynamically_registered: true)

    get_consent_screen client: client

    assert_response :success
    assert_select "strong", text: "connector.example.com:8443"
  end

  test "denying a self-registered https client still redirects, after the consent screen named its host" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], dynamically_registered: true)

    post_consent client: client, error: "access_denied"

    assert_response :redirect
    assert_match %r{\Ahttps://connector\.example\.com/callback\?}, response.location
    assert_equal "access_denied", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
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


  test "authorization preselects Read + Write when the client requests read write" do
    sign_in_as :david

    get_consent_screen scope: "read write"

    assert_response :success
    assert_select "select[name=scope] option[selected]", count: 1
    assert_select "select[name=scope] option[selected][value=?]", "read write"
  end

  test "authorization preselects Read + Write when the client requests write" do
    sign_in_as :david

    get_consent_screen scope: "write"

    assert_response :success
    assert_select "select[name=scope] option[selected][value=?]", "read write"
  end

  test "authorization preselects Read for a read request" do
    sign_in_as :david

    get_consent_screen scope: "read"

    assert_response :success
    assert_select "select[name=scope] option[selected][value=?]", "read"
  end

  test "authorization offers no write option to a read-only client" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Reader", redirect_uris: %w[ http://127.0.0.1:8888/callback ], scopes: %w[ read ], dynamically_registered: true)

    get_consent_screen client: client, scope: "read"

    assert_response :success
    assert_select "select[name=scope] option", count: 1
    assert_select "select[name=scope] option[value=?]", "read"
  end

  test "consent grants the canonical read write scope" do
    sign_in_as :david
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    post_consent scope: "read write", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        client_id: oauth_clients(:mcp_client).client_id,
        code: code,
        redirect_uri: "http://127.0.0.1:8888/callback",
        code_verifier: code_verifier
      }, as: :json
    end

    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
    assert_equal "write", Identity::AccessToken.find_by(token: response.parsed_body["access_token"]).permission
  end

  test "authorization redirects carry the issuer from the metadata (RFC 9207)" do
    sign_in_as :david

    untenanted { get "/.well-known/oauth-authorization-server" }
    issuer = response.parsed_body["issuer"]
    assert_predicate issuer, :present?

    post_consent
    assert_equal issuer, Rack::Utils.parse_query(URI.parse(response.location).query)["iss"]

    post_consent error: "access_denied"
    denied = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal "access_denied", denied["error"]
    assert_equal issuer, denied["iss"]

    get_consent_screen code_challenge: nil
    assert_response :redirect
    invalid = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal "invalid_request", invalid["error"]
    assert_equal issuer, invalid["iss"]
  end

  test "authorization redirect keeps the registered query alongside iss" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "Query", redirect_uris: %w[ https://app.example.com/cb?tenant=acme ], scopes: %w[ read ])

    post_consent client: client, redirect_uri: "https://app.example.com/cb?tenant=acme"

    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal "acme", query["tenant"]
    assert_equal "http://www.example.com/", query["iss"]
  end

  test "consent screen lets the form redirect to the validated loopback origin" do
    sign_in_as :david

    get_consent_screen redirect_uri: "http://127.0.0.1:53682/callback"

    assert_response :success
    assert_equal [ "'self'", "http://127.0.0.1:53682" ], form_action_sources
  end

  test "consent screen lets the form redirect to the validated https origin" do
    sign_in_as :david

    get_consent_screen client: oauth_clients(:trusted_client), redirect_uri: "https://app.example.com/oauth/callback"

    assert_response :success
    assert_equal [ "'self'", "https://app.example.com" ], form_action_sources
  end

  test "consent screen allows only the http scheme for an IPv6 loopback, which CSP cannot name" do
    sign_in_as :david
    client = Oauth::Client.create!(name: "IPv6", redirect_uris: %w[ http://[::1]:8888/callback ], dynamically_registered: true)

    get_consent_screen client: client, redirect_uri: "http://[::1]:9999/callback"

    assert_response :success
    assert_equal [ "'self'", "http:" ], form_action_sources
  end

  test "an unvalidated redirect_uri adds nothing to form-action" do
    sign_in_as :david

    get_consent_screen redirect_uri: "http://evil.com/steal"

    assert_response :bad_request
    assert_equal [ "'self'" ], form_action_sources
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
          client_id: oauth_clients(:mcp_client).client_id,
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: code_verifier
        }, as: :json
      end
    end

    assert_response :success
    body = response.parsed_body

    assert_not_nil body["access_token"]
    assert_not_nil body["refresh_token"]
    assert_operator body["expires_in"], :>, 0
    assert_equal "Bearer", body["token_type"]
    assert_equal "read", body["scope"]

    token = Identity::AccessToken.find_by(token: body["access_token"])
    assert_equal client, token.oauth_client
    assert_equal identity, token.identity
    assert_equal "read", token.permission
  end

  test "token exchange reports a legacy write scope canonically" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:mcp_client)

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        client_id: client.client_id,
        code: authorization_code_for(client, code_verifier: code_verifier, scope: "write"),
        redirect_uri: "http://127.0.0.1:8888/callback",
        code_verifier: code_verifier
      }, as: :json
    end

    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
  end

  test "token exchange rejects invalid code" do
    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        client_id: oauth_clients(:mcp_client).client_id,
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
        client_id: oauth_clients(:mcp_client).client_id,
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
        client_id: oauth_clients(:mcp_client).client_id,
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
          client_id: oauth_clients(:mcp_client).client_id,
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

  test "token exchange requires grant_type" do
    untenanted do
      post oauth_token_path, params: { code: "code" }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "token exchange requires code, code_verifier, redirect_uri and client_id" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:mcp_client)
    code = authorization_code_for(client, code_verifier: code_verifier)
    complete = { grant_type: "authorization_code", code: code, code_verifier: code_verifier,
      redirect_uri: "http://127.0.0.1:8888/callback", client_id: client.client_id }

    %i[ code code_verifier redirect_uri client_id ].each do |name|
      assert_no_difference "Identity::AccessToken.count" do
        untenanted { post oauth_token_path, params: complete.except(name), as: :json }
      end

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body["error"], "missing #{name}"
      assert_match name.to_s, response.parsed_body["error_description"]
    end
  end

  test "token exchange rejects non-string parameters as a malformed request" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:mcp_client)
    complete = { grant_type: "authorization_code", code_verifier: code_verifier,
      redirect_uri: "http://127.0.0.1:8888/callback", client_id: client.client_id }

    %i[ code code_verifier redirect_uri client_id ].each do |name|
      request = complete.merge(code: authorization_code_for(client, code_verifier: code_verifier))

      [ [ request[name] ], { "value" => request[name] }, 1 ].each do |malformed|
        assert_no_difference "Identity::AccessToken.count" do
          untenanted { post oauth_token_path, params: request.merge(name => malformed), as: :json }
        end

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body["error"], "#{name} as #{malformed.class}"
        assert_match name.to_s, response.parsed_body["error_description"]
      end
    end
  end

  test "token exchange rejects a code issued to another client" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code = authorization_code_for(oauth_clients(:mcp_client), code_verifier: code_verifier)

    assert_no_difference "Identity::AccessToken.count" do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          client_id: oauth_clients(:trusted_client).client_id,
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: code_verifier
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "token exchange rejects a reused code and revokes the grant it issued" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:mcp_client)
    code = authorization_code_for(client, code_verifier: code_verifier)
    exchange = { grant_type: "authorization_code", client_id: client.client_id, code: code,
      redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }

    untenanted { post oauth_token_path, params: exchange, as: :json }
    assert_response :success
    first_token = response.parsed_body["access_token"]
    assert Identity::AccessToken.exists?(token: first_token)

    assert_difference "Identity::AccessToken.count", -1 do
      untenanted { post oauth_token_path, params: exchange, as: :json }
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_not Identity::AccessToken.exists?(token: first_token)

    fresh_code = authorization_code_for(client, code_verifier: code_verifier)
    untenanted { post oauth_token_path, params: exchange.merge(code: fresh_code), as: :json }
    assert_response :success
  end

  test "a replayed code that fails PKCE does not revoke the grant" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:mcp_client)
    code = authorization_code_for(client, code_verifier: code_verifier)
    exchange = { grant_type: "authorization_code", client_id: client.client_id, code: code,
      redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }

    untenanted { post oauth_token_path, params: exchange, as: :json }
    assert_response :success
    first_token = response.parsed_body["access_token"]

    untenanted { post oauth_token_path, params: exchange.merge(code_verifier: "wrong_verifier"), as: :json }
    assert_response :bad_request
    assert Identity::AccessToken.exists?(token: first_token)
  end


  test "token endpoint accepts form-encoded requests with forgery protection active" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: oauth_clients(:mcp_client).client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read"

    with_forgery_protection do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          client_id: oauth_clients(:mcp_client).client_id,
          code: code,
          redirect_uri: "http://127.0.0.1:8888/callback",
          code_verifier: code_verifier
        }, headers: { "X-Forwarded-Proto" => "https" }
      end
    end

    assert_response :success
    assert_not_nil response.parsed_body["access_token"]
  end


  # Confidential Clients (client_secret_post)

  test "token exchange for confidential client requires client secret" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "https://connector.example.com/callback",
      scope: "read"

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        client_id: client.client_id,
        code: code,
        redirect_uri: "https://connector.example.com/callback",
        code_verifier: code_verifier
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]

    # Naming no client at all is a malformed request, whatever the code.
    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "https://connector.example.com/callback",
        code_verifier: code_verifier
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "token exchange for confidential client rejects a wrong client secret" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "https://connector.example.com/callback",
      scope: "read"

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "https://connector.example.com/callback",
        code_verifier: code_verifier,
        client_secret: "wrong"
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]
  end

  test "token exchange for confidential client rejects a non-string client secret" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "https://connector.example.com/callback",
      scope: "read"

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "https://connector.example.com/callback",
        code_verifier: code_verifier,
        client_secret: [ "confidential_secret_789" ]
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]
  end

  test "token exchange for confidential client succeeds with the client secret" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "https://connector.example.com/callback",
      scope: "read"

    assert_difference "Identity::AccessToken.count", 1 do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: "https://connector.example.com/callback",
          code_verifier: code_verifier,
          client_id: client.client_id,
          client_secret: "confidential_secret_789"
        }, as: :json
      end
    end

    assert_response :success
    assert_not_nil response.parsed_body["access_token"]
  end

  test "token exchange for confidential client rejects credentials in the query string" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "https://connector.example.com/callback",
      scope: "read"

    untenanted do
      post oauth_token_path(client_id: client.client_id, client_secret: "confidential_secret_789"), params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "https://connector.example.com/callback",
        code_verifier: code_verifier
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]
  end

  test "token exchange for confidential client requires a matching client_id" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    code = Oauth::AuthorizationCode.generate \
      client_id: client.client_id,
      identity_id: identities(:david).id,
      code_challenge: code_challenge,
      redirect_uri: "https://connector.example.com/callback",
      scope: "read"

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: "https://connector.example.com/callback",
        code_verifier: code_verifier,
        client_secret: "confidential_secret_789"
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]
  end

  test "refresh grant for confidential client requires the client secret" do
    client = oauth_clients(:confidential_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_id: client.client_id
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_id: client.client_id,
        client_secret: "confidential_secret_789"
      }, as: :json
    end

    assert_response :success
  end

  test "code grant for confidential client with a missing or wrong client_id fails as invalid_client" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:confidential_client)
    exchange = { grant_type: "authorization_code", client_secret: "confidential_secret_789",
      code: authorization_code_for(client, code_verifier: code_verifier),
      redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }

    [ {}, { client_id: oauth_clients(:mcp_client).client_id } ].each do |client_id|
      assert_no_difference "Identity::AccessToken.count" do
        untenanted { post oauth_token_path, params: exchange.merge(client_id), as: :json }
      end

      assert_response :bad_request
      assert_equal "invalid_client", response.parsed_body["error"]
    end
  end

  test "code grant for confidential client authenticates before checking the verifier or redirect_uri" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:confidential_client)
    exchange = { grant_type: "authorization_code", client_id: client.client_id, client_secret: "wrong",
      code: authorization_code_for(client, code_verifier: code_verifier),
      redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }

    [ { code_verifier: "not-the-verifier" }, { redirect_uri: "http://127.0.0.1:8888/elsewhere" } ].each do |mismatch|
      untenanted { post oauth_token_path, params: exchange.merge(mismatch), as: :json }

      assert_response :bad_request
      assert_equal "invalid_client", response.parsed_body["error"]
    end
  end

  test "token errors are never cached" do
    client = oauth_clients(:confidential_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)

    [ { grant_type: "password" },
      { grant_type: "refresh_token", refresh_token: token.refresh_token, client_id: client.client_id, client_secret: "wrong" },
      { grant_type: "refresh_token", refresh_token: "bogus", client_id: oauth_clients(:mcp_client).client_id } ].each do |request|
      untenanted { post oauth_token_path, params: request, as: :json }

      assert_response :bad_request
      assert_equal "no-store", response.headers["Cache-Control"], request.inspect
      assert_equal "no-cache", response.headers["Pragma"]
    end
  end

  test "registration errors are never cached" do
    untenanted { post oauth_clients_path, params: { redirect_uris: [] }, as: :json }

    assert_response :bad_request
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "confidential client authentication does not reveal whether a refresh token is live" do
    client = oauth_clients(:confidential_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)

    [ token.refresh_token, "not-a-refresh-token" ].each do |refresh_token|
      untenanted { post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: client.client_id, client_secret: "wrong" }, as: :json }
      assert_equal "invalid_client", response.parsed_body["error"], "wrong secret"

      untenanted { post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: oauth_clients(:mcp_client).client_id }, as: :json }
      assert_equal "invalid_grant", response.parsed_body["error"], "another client's id"

      untenanted { post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token }, as: :json }
      assert_equal "invalid_request", response.parsed_body["error"], "no client_id"
    end

    assert_equal token.refresh_token, token.reload.refresh_token
  end

  test "confidential client authentication does not reveal whether a code is valid" do
    client = oauth_clients(:confidential_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    [ authorization_code_for(client, code_verifier: code_verifier), "not-a-code" ].each do |code|
      untenanted do
        post oauth_token_path, params: { grant_type: "authorization_code", client_id: client.client_id, client_secret: "wrong",
          code: code, redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }, as: :json
      end

      assert_equal "invalid_client", response.parsed_body["error"]
    end
  end

  test "refresh grant for confidential client omitting client_id fails as invalid_client" do
    client = oauth_clients(:confidential_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_secret: "confidential_secret_789"
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client", response.parsed_body["error"]
  end


  # Refresh Grant

  test "refresh grant rotates access and refresh tokens" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)
    old_access_token, old_refresh_token = token.token, token.refresh_token

    assert_no_difference "Identity::AccessToken.count" do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "refresh_token",
          refresh_token: old_refresh_token,
          client_id: client.client_id
        }, as: :json
      end
    end

    assert_response :success
    body = response.parsed_body

    assert_not_nil body["access_token"]
    assert_not_nil body["refresh_token"]
    assert_operator body["expires_in"], :>, 0
    assert_not_equal old_access_token, body["access_token"]
    assert_not_equal old_refresh_token, body["refresh_token"]
  end

  test "refresh grant requires refresh_token and client_id" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)
    complete = { grant_type: "refresh_token", refresh_token: token.refresh_token, client_id: client.client_id }

    %i[ refresh_token client_id ].each do |name|
      untenanted { post oauth_token_path, params: complete.except(name), as: :json }

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body["error"], "missing #{name}"
      assert_match name.to_s, response.parsed_body["error_description"]
    end

    assert_equal complete[:refresh_token], token.reload.refresh_token
  end

  test "refresh grant rejects non-string refresh_token and client_id as a malformed request" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)
    complete = { grant_type: "refresh_token", refresh_token: token.refresh_token, client_id: client.client_id }

    %i[ refresh_token client_id ].each do |name|
      [ [ complete[name] ], { "value" => complete[name] }, 1 ].each do |malformed|
        untenanted { post oauth_token_path, params: complete.merge(name => malformed), as: :json }

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body["error"], "#{name} as #{malformed.class}"
        assert_match name.to_s, response.parsed_body["error_description"]
      end
    end

    assert_equal complete[:refresh_token], token.reload.refresh_token
  end

  test "a reused code revokes the grant it issued, refreshed or not" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    client = oauth_clients(:mcp_client)
    exchange = { grant_type: "authorization_code", client_id: client.client_id,
      code: authorization_code_for(client, code_verifier: code_verifier),
      redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }

    untenanted { post oauth_token_path, params: exchange, as: :json }
    assert_response :success

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token",
        refresh_token: response.parsed_body["refresh_token"], client_id: client.client_id }, as: :json
    end
    assert_response :success
    refreshed = response.parsed_body

    untenanted { post oauth_token_path, params: exchange, as: :json }
    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]

    assert_not Identity::AccessToken.exists?(token: refreshed["access_token"])
    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token",
        refresh_token: refreshed["refresh_token"], client_id: client.client_id }, as: :json
    end
    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "refresh grant echoes the granted scope" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client, permission: :write)

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_id: client.client_id
      }, as: :json
    end

    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
  end

  test "code exchange and refresh report a write grant the same way" do
    client = oauth_clients(:mcp_client)
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    untenanted do
      post oauth_token_path, params: { grant_type: "authorization_code", client_id: client.client_id,
        code: authorization_code_for(client, code_verifier: code_verifier, scope: "read write"),
        redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: code_verifier }, as: :json
    end
    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token",
        refresh_token: response.parsed_body["refresh_token"], client_id: client.client_id }, as: :json
    end
    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
  end

  test "refresh grant narrows the token to a requested subset scope" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client, permission: :write)

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_id: client.client_id,
        scope: "read"
      }, as: :json
    end

    assert_response :success
    assert_equal "read", response.parsed_body["scope"]
    assert_equal "read", Identity::AccessToken.find_by(token: response.parsed_body["access_token"]).permission
  end

  test "refresh grant rejects a scope broader than the original grant" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client, permission: :read)
    old_refresh_token = token.refresh_token

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: old_refresh_token,
        client_id: client.client_id,
        scope: "write"
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]
    assert_equal old_refresh_token, token.reload.refresh_token
  end

  test "refresh grant rejects a blank scope rather than restoring the full grant" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client, permission: :write)
    old_refresh_token = token.refresh_token

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: old_refresh_token,
        client_id: client.client_id,
        scope: " "
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]
    assert_equal old_refresh_token, token.reload.refresh_token
  end

  test "refresh grant rejects an explicit null scope rather than restoring the full grant" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client, permission: :write)
    old_refresh_token = token.refresh_token

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: old_refresh_token,
        client_id: client.client_id,
        scope: nil
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]
    assert_equal old_refresh_token, token.reload.refresh_token
  end

  test "refresh grant works after the access token expires" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)

    travel Identity::AccessToken::EXPIRES_IN + 1.minute do
      untenanted do
        post oauth_token_path, params: {
          grant_type: "refresh_token",
          refresh_token: token.refresh_token,
          client_id: client.client_id
        }, as: :json
      end

      assert_response :success
      assert_not Identity::AccessToken.find_by(token: response.parsed_body["access_token"]).expired?
    end
  end

  test "refresh grant invalidates the previous refresh token" do
    client = oauth_clients(:mcp_client)
    token = identities(:david).access_tokens.create!(oauth_client: client)
    old_refresh_token = token.refresh_token

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: old_refresh_token,
        client_id: client.client_id
      }, as: :json
    end
    assert_response :success

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: old_refresh_token,
        client_id: client.client_id
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "refresh grant rejects a client mismatch" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_id: oauth_clients(:trusted_client).client_id
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "refresh grant rejects unknown refresh token" do
    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: "nonexistent",
        client_id: oauth_clients(:mcp_client).client_id
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "refresh grant rejects blank refresh token as a malformed request" do
    untenanted do
      post oauth_token_path, params: {
        grant_type: "refresh_token",
        refresh_token: "",
        client_id: oauth_clients(:mcp_client).client_id
      }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
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

  test "revocation by refresh token revokes the grant" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_difference "Identity::AccessToken.count", -1 do
      untenanted do
        post oauth_revocation_path, params: { token: token.refresh_token }, as: :json
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
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "revocation without a token answers invalid_request, form-encoded or JSON" do
    untenanted do
      post oauth_revocation_path, params: { token_type_hint: "access_token" }
    end
    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]

    untenanted do
      post oauth_revocation_path, params: {}, as: :json
    end
    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "revocation ignores client credentials and revokes on the token alone" do
    access_token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :read)

    untenanted do
      post oauth_revocation_path, params: { token: access_token.token },
        headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("someone", "anything") }
    end

    assert_response :success
    assert_not Identity::AccessToken.exists?(access_token.id)
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
    assert_equal true, body["authorization_response_iss_parameter_supported"]
    assert_equal %w[ query ], body["response_modes_supported"]
    assert_match %r{/oauth/revocation$}, body["revocation_endpoint"]
    assert_equal %w[ none ], body["revocation_endpoint_auth_methods_supported"]
    assert_includes body["grant_types_supported"], "authorization_code"
    assert_includes body["grant_types_supported"], "refresh_token"
    assert_includes body["token_endpoint_auth_methods_supported"], "none"
    assert_includes body["token_endpoint_auth_methods_supported"], "client_secret_post"
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
    assert_equal %w[ authorization_code refresh_token ], body["grant_types"]
  end

  test "DCR registering write also registers read, which write implies" do
    untenanted do
      post oauth_clients_path, params: {
        client_name: "Writer",
        redirect_uris: [ "http://127.0.0.1:8888/callback" ],
        scope: "write"
      }, as: :json
    end

    assert_response :created
    assert_equal "read write", response.parsed_body["scope"]
    assert_equal %w[ read write ], Oauth::Client.find_by(client_id: response.parsed_body["client_id"]).scopes
  end

  test "DCR creates client with https redirect" do
    assert_difference "Oauth::Client.count", 1 do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Hosted Connector",
          redirect_uris: [ "https://connector.example.com/callback" ]
        }, as: :json
      end
    end

    assert_response :created
    body = response.parsed_body

    assert_not_nil body["client_id"]
    assert_equal [ "https://connector.example.com/callback" ], body["redirect_uris"]
  end

  test "DCR rejects plain http non-loopback redirect" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Evil Client",
          redirect_uris: [ "http://evil.com/steal" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "DCR rejects a client_name longer than 255 characters" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "a" * 256,
          redirect_uris: [ "http://127.0.0.1:8888/callback" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", response.parsed_body["error"]
  end

  test "DCR accepts a 255-character client_name" do
    untenanted do
      post oauth_clients_path, params: {
        client_name: "a" * 255,
        redirect_uris: [ "http://127.0.0.1:8888/callback" ]
      }, as: :json
    end

    assert_response :created
    assert_equal "a" * 255, response.parsed_body["client_name"]
  end

  test "DCR falls back to the default name for a non-string client_name" do
    untenanted do
      post oauth_clients_path, params: {
        client_name: { "en" => "Sneaky" },
        redirect_uris: [ "http://127.0.0.1:8888/callback" ]
      }, as: :json
    end

    assert_response :created
    assert_equal "MCP Client", response.parsed_body["client_name"]
  end

  test "DCR rejects https loopback redirect" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "HTTPS Loopback",
          redirect_uris: [ "https://127.0.0.1:8888/callback" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "DCR rejects https loopback redirect regardless of host case" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Cased Loopback",
          redirect_uris: [ "https://LOCALHOST:8888/callback" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "DCR rejects percent-encoded https loopback redirect" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Encoded Loopback",
          redirect_uris: [ "https://%6cocalhost:8888/callback" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "DCR rejects a redirect whose authority isn't plain" do
    %w[ https://%65vil.example/callback https://user:secret@connector.example.com/callback
        https://connector.example.com:65536/callback http://user@127.0.0.1:8888/callback http://%5B%3A%3A1%5D:8888/callback ].each do |uri|
      assert_no_difference "Oauth::Client.count" do
        untenanted { post oauth_clients_path, params: { client_name: "Unplain", redirect_uris: [ uri ] }, as: :json }
      end

      assert_response :bad_request, uri
      assert_equal "invalid_redirect_uri", response.parsed_body["error"], uri
    end
  end

  test "DCR rejects a redirect whose host decodes to invalid UTF-8" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Broken Host",
          redirect_uris: [ "https://%FF/callback" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "DCR rejects https redirect with fragment" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Fragment Client",
          redirect_uris: [ "https://connector.example.com/callback#section" ]
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "https redirect requires exact match in authorization" do
    sign_in_as :david

    untenanted do
      post oauth_clients_path, params: {
        client_name: "Hosted Connector",
        redirect_uris: [ "https://connector.example.com/callback" ]
      }, as: :json
    end
    client_id = response.parsed_body["client_id"]

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client_id,
        redirect_uri: "https://connector.example.com/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end
    assert_response :success
    assert_match "connector.example.com", response.body

    untenanted do
      get new_oauth_authorization_path, params: {
        client_id: client_id,
        redirect_uri: "https://connector.example.com:8443/callback",
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }
    end
    assert_response :bad_request
  end

  test "DCR registers a confidential client with client_secret_post" do
    untenanted do
      post oauth_clients_path, params: {
        client_name: "Hosted Connector",
        redirect_uris: [ "https://connector.example.com/callback" ],
        token_endpoint_auth_method: "client_secret_post"
      }, as: :json
    end

    assert_response :created
    body = response.parsed_body

    assert_equal "client_secret_post", body["token_endpoint_auth_method"]
    assert_not_nil body["client_secret"]
    assert_equal 0, body["client_secret_expires_at"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert Oauth::Client.find_by(client_id: body["client_id"]).confidential?
  end

  test "DCR omits client_secret for public clients" do
    untenanted do
      post oauth_clients_path, params: {
        client_name: "Public Client",
        redirect_uris: [ "http://127.0.0.1:8888/callback" ]
      }, as: :json
    end

    assert_response :created
    body = response.parsed_body

    assert_equal "none", body["token_endpoint_auth_method"]
    assert_not body.key?("client_secret")
    assert_not body.key?("client_secret_expires_at")
  end

  test "DCR rejects unsupported token_endpoint_auth_method" do
    assert_no_difference "Oauth::Client.count" do
      untenanted do
        post oauth_clients_path, params: {
          client_name: "Basic Client",
          redirect_uris: [ "https://connector.example.com/callback" ],
          token_endpoint_auth_method: "client_secret_basic"
        }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", response.parsed_body["error"]
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
          client_id: oauth_clients(:mcp_client).client_id,
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

  private
    def get_consent_screen(client: oauth_clients(:mcp_client), **params)
      untenanted do
        get new_oauth_authorization_path, params: consent_params(client, **params).compact
      end
    end

    def post_consent(client: oauth_clients(:mcp_client), **params)
      untenanted do
        post oauth_authorization_path, params: consent_params(client, **params).compact
      end
    end

    def consent_params(client, **overrides)
      {
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        response_type: "code",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }.merge(overrides)
    end

    def form_action_sources
      response.headers["Content-Security-Policy"].split(";").map(&:strip) \
        .find { |directive| directive.start_with?("form-action ") }.split.drop(1)
    end

    def authorization_code_for(client, code_verifier:, identity: identities(:david), scope: "read")
      Oauth::AuthorizationCode.generate \
        client_id: client.client_id,
        identity_id: identity.id,
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
        redirect_uri: "http://127.0.0.1:8888/callback",
        scope: scope
    end

    def with_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
end
