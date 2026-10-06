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

  test "authorization errors for a self-registered loopback client still redirect" do
    sign_in_as :david

    get_consent_screen code_challenge: nil

    assert_response :redirect
    assert_equal "invalid_request", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
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
