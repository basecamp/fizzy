require "test_helper"

# The Active Support notifications OAuth endpoints announce for metrics
# (Yabeda::Oauth subscribes in SaaS). Labels come from fixed sets, never from
# the request.
class OauthInstrumentationTest < ActionDispatch::IntegrationTest
  include OauthClientCredentialsTestHelper

  setup do
    @client = oauth_clients(:mcp_client)
  end

  test "a token request is timed under its grant type" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :read)

    payloads = notifications("token_request.oauth") { refresh grant.raw_refresh_token }

    assert_response :success
    assert_equal [ { grant_type: "refresh_token" } ], payloads
  end

  test "an unsupported grant type is timed as unknown" do
    payloads = notifications("token_request.oauth") do
      untenanted { post oauth_token_path, params: { grant_type: "made_up_#{SecureRandom.hex}", client_id: @client.client_id } }
    end

    assert_equal [ { grant_type: "unknown" } ], payloads
  end

  test "a token error names its code and the client's type" do
    payloads = notifications("error.oauth") { refresh "fizzy_rt_unknown" }

    assert_equal [ { endpoint: "tokens", error_code: "invalid_grant", client_type: "public" } ], payloads
  end

  test "failed client authentication is an invalid_client error for the confidential client named" do
    client = oauth_clients(:confidential_client)

    payloads = notifications("error.oauth") do
      untenanted { post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: "x" }, headers: basic(client.client_id, "wrong") }
    end

    assert_client_authentication_failed
    assert_equal [ { endpoint: "tokens", error_code: "invalid_client", client_type: "confidential" } ], payloads
  end

  test "an error is labeled with the client that asked, not the one the code was issued to" do
    code = Oauth::AuthorizationCode.generate client_id: oauth_clients(:confidential_client).client_id, identity_id: identities(:david).id,
      code_challenge: "challenge", redirect_uri: "https://connector.example.com/callback", scope: "read"

    payloads = notifications("error.oauth") do
      untenanted do
        post oauth_token_path, params: { grant_type: "authorization_code", code: code, code_verifier: "v" * 43,
          redirect_uri: "https://connector.example.com/callback", client_id: @client.client_id }
      end
    end

    assert_equal [ { endpoint: "tokens", error_code: "invalid_grant", client_type: "public" } ], payloads
  end

  test "an error for a client that doesn't exist is labeled unknown" do
    payloads = notifications("error.oauth") { refresh "fizzy_rt_unknown", client_id: "nobody_#{SecureRandom.hex}" }

    assert_equal "unknown", payloads.sole[:client_type]
  end

  test "a rejected registration is a clients error" do
    payloads = notifications("error.oauth") do
      untenanted { post oauth_clients_path, as: :json, params: { redirect_uris: %w[ http://example.com/callback ] } }
    end

    assert_equal [ { endpoint: "clients", error_code: "invalid_redirect_uri", client_type: "unknown" } ], payloads
  end

  test "a throttled request is a rate-limit hit, not an error" do
    ActiveSupport::Cache::NullStore.any_instance.stubs(:increment).returns(21)

    errors = []
    hits = notifications("rate_limit.oauth") do
      errors = notifications("error.oauth") { refresh "fizzy_rt_unknown" }
    end

    assert_response :too_many_requests
    assert_equal [ { endpoint: "tokens" } ], hits
    assert_empty errors
  end

  private
    def notifications(name)
      payloads = []
      callback = ->(event) { payloads << event.payload.dup }
      ActiveSupport::Notifications.subscribed(callback, name) { yield }
      payloads
    end

    def refresh(refresh_token, client_id: @client.client_id)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: client_id }
      end
    end
end
