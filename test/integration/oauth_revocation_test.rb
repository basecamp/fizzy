require "test_helper"

# RFC 7009 §2.1: the server validates the client's credentials and that the
# token was issued to it.
class OauthRevocationTest < ActionDispatch::IntegrationTest
  include OauthClientCredentialsTestHelper

  setup do
    @client = oauth_clients(:confidential_client)
    @secret = "confidential_secret_789"
  end

  # Revocation (RFC 7009 §2.1)

  test "a confidential client must authenticate to revoke" do
    token = grant_for(@client)

    [ { client_id: @client.client_id }, { client_id: @client.client_id, client_secret: "wrong" } ].each do |credentials|
      revoke token.token, params: credentials

      assert_client_authentication_failed credentials.inspect, basic: false
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "a confidential client revokes its own token with client_secret_post or Basic" do
    [ [ { client_id: @client.client_id, client_secret: @secret }, {} ], [ {}, basic(@client.client_id, @secret) ] ].each do |params, headers|
      token = grant_for(@client)

      revoke token.refresh_token, params: params, headers: headers

      assert_response :success
      assert_not Identity::AccessToken.exists?(token.id)
    end
  end

  test "an authenticated confidential client cannot revoke another client's token, and is told nothing" do
    token = grant_for(oauth_clients(:mcp_client))

    [ token.token, token.refresh_token ].each do |presented|
      revoke presented, headers: basic(@client.client_id, @secret)

      assert_response :success
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "a public client revokes its own token by naming its client_id" do
    client = oauth_clients(:mcp_client)

    [ :token, :refresh_token ].each do |kind|
      token = grant_for(client)

      revoke token.public_send(kind), params: { client_id: client.client_id }

      assert_response :success
      assert_not Identity::AccessToken.exists?(token.id), kind
    end
  end

  test "a public client naming no client, or another client, revokes nothing and is told nothing" do
    token = grant_for(oauth_clients(:mcp_client))

    [ {}, { client_id: oauth_clients(:trusted_client).client_id }, { client_id: "no-such-client" } ].each do |params|
      revoke token.token, params: params

      assert_response :success, params.inspect
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "an unknown token answers 200" do
    revoke "not-a-token", params: { client_id: oauth_clients(:mcp_client).client_id }
    assert_response :success

    revoke "not-a-token", headers: basic(@client.client_id, @secret)
    assert_response :success
  end

  # A personal access token has no client, so possession is the credential:
  # whoever holds one may revoke it, the same as signing out of it.

  test "a personal access token is revoked by whoever presents it" do
    [ {}, { client_id: oauth_clients(:mcp_client).client_id }, { client_id: "no-such-client" } ].each do |params|
      token = personal_token

      revoke token.token, params: params

      assert_response :success, params.inspect
      assert_not Identity::AccessToken.exists?(token.id), params.inspect
    end
  end

  test "a personal access token is revoked beside client credentials that authenticate" do
    [ [ { client_id: @client.client_id, client_secret: @secret }, {} ], [ {}, basic(@client.client_id, @secret) ] ].each do |params, headers|
      token = personal_token

      revoke token.token, params: params, headers: headers

      assert_response :success
      assert_not Identity::AccessToken.exists?(token.id)
    end
  end

  test "client credentials that fail to authenticate are refused before a personal access token is revoked" do
    token = personal_token

    [ [ { client_id: @client.client_id }, {}, false ], [ { client_id: @client.client_id, client_secret: "wrong" }, {}, false ],
      [ { client_secret: @secret }, {}, false ], [ { client_id: oauth_clients(:mcp_client).client_id, client_secret: "anything" }, {}, false ],
      [ {}, basic(@client.client_id, "wrong"), true ], [ {}, basic("no-such-client", "x"), true ] ].each do |params, headers, via_basic|
      revoke token.token, params: params, headers: headers

      assert_client_authentication_failed [ params, headers ].inspect, basic: via_basic
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "a personal access token is not revoked by two client authentication methods at once" do
    token = personal_token

    revoke token.token, params: { client_secret: @secret }, headers: basic(@client.client_id, @secret)

    assert_response :bad_request
    assert Identity::AccessToken.exists?(token.id)
  end

  test "a revoked personal access token no longer authenticates" do
    token = personal_token
    get user_path(users(:david)), env: { "HTTP_AUTHORIZATION" => "Bearer #{token.token}" }, as: :json
    assert_response :success

    revoke token.token

    get user_path(users(:david)), env: { "HTTP_AUTHORIZATION" => "Bearer #{token.token}" }, as: :json
    assert_response :unauthorized
  end

  test "a Basic header that fails to authenticate is refused at revocation, whatever the token" do
    token = grant_for(oauth_clients(:mcp_client))

    [ basic("no-such-client", "x"), basic(@client.client_id, "wrong"), basic(oauth_clients(:mcp_client).client_id, "") ].each do |headers|
      [ token.token, "not-a-token" ].each do |presented|
        revoke presented, headers: headers

        assert_client_authentication_failed presented
      end
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "a body client_secret that authenticates no client is refused, whatever the token" do
    token = grant_for(@client)

    [ { client_secret: @secret }, { client_id: "no-such-client", client_secret: @secret },
      { client_id: oauth_clients(:mcp_client).client_id, client_secret: "anything" } ].each do |params|
      [ token.token, "not-a-token" ].each do |presented|
        revoke presented, params: params

        assert_client_authentication_failed params.inspect, basic: false
      end
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "a failed body authentication beside an Authorization header of another scheme is a 400: Basic was never evaluated" do
    token = grant_for(@client)

    revoke token.token, params: { client_id: @client.client_id, client_secret: "wrong" }, headers: { "Authorization" => "Bearer #{token.token}" }

    assert_client_authentication_failed basic: false
    assert Identity::AccessToken.exists?(token.id)
  end

  test "revocation refuses Basic beside a body client_secret" do
    token = grant_for(@client)

    revoke token.token, params: { client_secret: @secret }, headers: basic(@client.client_id, @secret)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert Identity::AccessToken.exists?(token.id)
  end

  # Revocation authenticates clients, so it is a place to guess secrets: it is
  # throttled like the token endpoint (RFC 6749 §2.3.1, RFC 7009 §5).
  test "revocation is rate limited like the token endpoint" do
    ActiveSupport::Cache::NullStore.any_instance.stubs(:increment).returns(21)

    revoke "not-a-token", params: { client_id: @client.client_id, client_secret: "guess" }

    assert_response :too_many_requests
    assert_equal "slow_down", response.parsed_body["error"]
  end

  test "metadata advertises client_secret_basic for revocation" do
    untenanted { get "/.well-known/oauth-authorization-server" }

    assert_equal %w[ none client_secret_post client_secret_basic ], response.parsed_body["revocation_endpoint_auth_methods_supported"]
  end

  private
    def personal_token
      identities(:david).access_tokens.create!(permission: :read)
    end

    def grant_for(client)
      identities(:david).access_tokens.create!(oauth_client: client, permission: :read)
    end

    def revoke(token, params: {}, headers: {})
      untenanted { post oauth_revocation_path, params: { token: token }.merge(params), headers: headers }
    end
end
