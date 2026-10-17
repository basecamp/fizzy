require "test_helper"

# Each OAuth lifecycle change reports its audit event (AU-1, Oauth::Audit),
# with the standard fields and never a credential.
class OauthAuditTest < ActionDispatch::IntegrationTest
  include OauthAuditTestHelper

  VERIFIER = "dBjftJeZ4CVP-mJ92K9OsQdq2VqrkaKUX38OaoPvBqg"
  CHALLENGE = Base64.urlsafe_encode64(Digest::SHA256.digest(VERIFIER), padding: false)
  REDIRECT_URI = "http://127.0.0.1:8888/callback"

  setup do
    @client = oauth_clients(:mcp_client)
    @identity = identities(:david)
  end

  test "showing, approving and denying consent" do
    sign_in_as :david

    events = capture_oauth_events do
      untenanted { get new_oauth_authorization_path, params: consent_params }
    end
    shown = oauth_event(events, "oauth.consent.shown")
    assert_equal @client.client_id, shown[:client_id]
    assert_equal "dcr", shown[:client_class]
    assert_equal "public", shown[:client_type]
    assert_equal @identity.id, shown[:identity_id]
    assert_equal "user", shown[:actor]
    assert_equal response.request.uuid, shown[:request_id]

    events = capture_oauth_events do
      untenanted { post oauth_authorization_path, params: consent_params }
    end
    assert_equal %w[ oauth.consent.approved oauth.code.issued ], oauth_event_names(events)
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    assert_no_secrets_in events, code

    events = capture_oauth_events do
      untenanted { post oauth_authorization_path, params: consent_params(error: "access_denied") }
    end
    assert_equal "user", oauth_event(events, "oauth.consent.denied")[:actor]
  end

  test "an error before the consent screen shows no consent" do
    sign_in_as :david

    events = capture_oauth_events do
      untenanted { get new_oauth_authorization_path, params: consent_params(code_challenge: nil) }
    end

    assert_empty events
  end

  test "exchanging a code redeems it, creates a grant and issues tokens" do
    events = capture_oauth_events { exchange authorization_code }

    assert_response :success
    grant = Identity::AccessToken.find_by_raw_token(response.parsed_body["access_token"])
    assert_equal %w[ oauth.code.redeemed oauth.grant.created oauth.token.issued ], oauth_event_names(events)

    issued = oauth_event(events, "oauth.token.issued")
    assert_equal grant.id, issued[:grant_id]
    assert_equal grant.id, issued[:family_id]
    assert_equal @identity.id, issued[:identity_id]
    assert_equal "authorization_code", issued[:grant_type]
    assert_equal "client", issued[:actor]
    assert_nil issued[:tenant_id]
    assert_no_secrets_in events, response.parsed_body["access_token"], response.parsed_body["refresh_token"]
  end

  test "a replayed code revokes the grant it issued" do
    code = authorization_code
    exchange code
    grant_id = Identity::AccessToken.find_by_raw_token(response.parsed_body["access_token"]).id

    events = capture_oauth_events { exchange code }

    assert_response :bad_request
    assert_equal %w[ oauth.code.replayed oauth.grant.revoked ], oauth_event_names(events)
    assert_equal grant_id, oauth_event(events, "oauth.code.replayed")[:grant_id]

    revoked = oauth_event(events, "oauth.grant.revoked")
    assert_equal grant_id, revoked[:grant_id]
    assert_equal "code_replayed", revoked[:reason]
    assert_equal "system", revoked[:actor]
  end

  test "refreshing, a retry within the grace window, and reuse past it" do
    freeze_time
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)
    presented = grant.raw_refresh_token

    events = capture_oauth_events { refresh presented }
    refreshed = oauth_event(events, "oauth.token.refreshed")
    assert_equal grant.id, refreshed[:grant_id]
    assert_equal "refresh_token", refreshed[:grant_type]
    successor = response.parsed_body
    assert_no_secrets_in events, presented, successor["access_token"], successor["refresh_token"]

    events = capture_oauth_events { refresh presented }
    assert_response :success
    assert_equal "answered", oauth_event(events, "oauth.token.grace_replay")[:reason]
    assert_no_secrets_in events, presented, successor["access_token"], successor["refresh_token"]

    travel Oauth::RetiredRefreshToken::GRACE
    events = capture_oauth_events { refresh presented }

    assert_equal %w[ oauth.token.reuse_detected oauth.grant.revoked ], oauth_event_names(events)
    revoked = oauth_event(events, "oauth.grant.revoked")
    assert_equal "reuse_detected", revoked[:reason]
    assert_equal "system", revoked[:actor]
  end

  test "a refresh that narrows scope narrows the grant" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :write)

    events = capture_oauth_events { refresh grant.raw_refresh_token, scope: "read" }

    assert_equal %w[ oauth.token.refreshed oauth.grant.narrowed ], oauth_event_names(events)
    assert_equal "read", oauth_event(events, "oauth.grant.narrowed")[:permission]

    events = capture_oauth_events { refresh response.parsed_body["refresh_token"], scope: "read" }
    assert_equal %w[ oauth.token.refreshed ], oauth_event_names(events)
  end

  test "a retry within the grace window that can't be answered says why" do
    freeze_time
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :write)
    presented = grant.raw_refresh_token
    refresh presented

    events = capture_oauth_events { refresh presented, scope: "read" }
    assert_equal "scope_mismatch", oauth_event(events, "oauth.token.grace_replay")[:reason]

    Oauth::RetiredRefreshToken.update_all successor_payload: nil
    events = capture_oauth_events { refresh presented }
    assert_equal "successor_gone", oauth_event(events, "oauth.token.grace_replay")[:reason]
  end

  test "a retry within the grace window after its successor has rotated is superseded" do
    freeze_time
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)
    presented = grant.raw_refresh_token
    refresh presented
    refresh response.parsed_body["refresh_token"]

    events = capture_oauth_events { refresh presented }

    assert_equal "superseded", oauth_event(events, "oauth.token.grace_replay")[:reason]
    assert Identity::AccessToken.exists?(grant.id)
  end

  test "revoking at the revocation endpoint, by either token" do
    { "access" => :raw_token, "refresh" => :raw_refresh_token }.each do |presented, token|
      grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)

      events = capture_oauth_events { revoke grant.public_send(token) }

      revoked = oauth_event(events, "oauth.grant.revoked")
      assert_equal grant.id, revoked[:grant_id]
      assert_equal "revocation_endpoint", revoked[:reason]
      assert_equal "client", revoked[:actor]
      assert_equal presented, revoked[:presented]
      assert_no_secrets_in events, grant.raw_token, grant.raw_refresh_token
    end
  end

  test "revoking a personal access token at the revocation endpoint" do
    pat = @identity.access_tokens.create!(permission: :read)

    events = capture_oauth_events { revoke pat.raw_token }

    revoked = oauth_event(events, "oauth.pat.revoked")
    assert_equal "pat", revoked[:client_class]
    assert_nil revoked[:client_id]
    assert_equal "access", revoked[:presented]
    assert_no_secrets_in events, pat.raw_token
  end

  test "an unknown token revokes nothing and reports nothing" do
    assert_empty capture_oauth_events { revoke "fizzy_at_unknown" }
  end

  test "disconnecting an app revokes each of its grants" do
    sign_in_as :david
    grants = 2.times.map { @identity.access_tokens.create!(oauth_client: @client, permission: :read) }

    events = capture_oauth_events { delete my_connected_app_path(@client) }

    assert_equal %w[ oauth.grant.revoked oauth.grant.revoked ], oauth_event_names(events)
    assert_equal grants.map(&:id).sort, events.map { |event| event[:payload][:grant_id] }.sort
    events.each do |event|
      assert_equal "disconnected", event[:payload][:reason]
      assert_equal "user", event[:payload][:actor]
    end
  end

  test "creating and revoking a personal access token" do
    sign_in_as :david

    events = capture_oauth_events do
      post my_access_tokens_path, params: { access_token: { description: "CLI", permission: "write" } }, as: :json
    end
    created = oauth_event(events, "oauth.pat.created")
    assert_equal "pat", created[:client_class]
    assert_equal "user", created[:actor]
    assert_equal "write", created[:permission]
    assert_no_secrets_in events, response.parsed_body["token"]

    events = capture_oauth_events { delete my_access_token_path(response.parsed_body["id"]), as: :json }
    revoked = oauth_event(events, "oauth.pat.revoked")
    assert_equal created[:grant_id], revoked[:grant_id]
    assert_equal "revoked", revoked[:reason]
    assert_equal "user", revoked[:actor]
  end

  test "registering a client" do
    events = capture_oauth_events do
      untenanted do
        post oauth_clients_path, as: :json, params: \
          { client_name: "Connector", redirect_uris: %w[ https://connector.example.com/callback ], token_endpoint_auth_method: "client_secret_post" }
      end
    end

    assert_response :created
    registered = oauth_event(events, "oauth.client.registered")
    assert_equal response.parsed_body["client_id"], registered[:client_id]
    assert_equal "dcr", registered[:client_class]
    assert_equal "confidential", registered[:client_type]
    assert_equal "client", registered[:actor]
    assert_no_secrets_in events, response.parsed_body["client_secret"]
  end

  test "a rejected registration registers nothing" do
    events = capture_oauth_events do
      untenanted { post oauth_clients_path, as: :json, params: { redirect_uris: %w[ http://example.com/callback ] } }
    end

    assert_response :bad_request
    assert_empty events
  end

  private
    def consent_params(**overrides)
      { client_id: @client.client_id, redirect_uri: REDIRECT_URI, response_type: "code", code_challenge: CHALLENGE,
        code_challenge_method: "S256", scope: "read", state: "xyz123" }.merge(overrides).compact
    end

    def authorization_code
      Oauth::AuthorizationCode.generate client_id: @client.client_id, identity_id: @identity.id,
        code_challenge: CHALLENGE, redirect_uri: REDIRECT_URI, scope: "read"
    end

    def exchange(code)
      untenanted do
        post oauth_token_path, params: \
          { grant_type: "authorization_code", code: code, code_verifier: VERIFIER, redirect_uri: REDIRECT_URI, client_id: @client.client_id }
      end
    end

    def refresh(refresh_token, **params)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id, **params }
      end
    end

    def revoke(token)
      untenanted { post oauth_revocation_path, params: { token: token, client_id: @client.client_id } }
    end
end
