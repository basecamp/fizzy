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

      assert_client_authentication_failed credentials.inspect
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

  test "a personal access token is no client's to revoke" do
    token = identity_access_tokens(:davids_api_token)

    revoke token.token, params: { client_id: oauth_clients(:mcp_client).client_id }

    assert_response :success
    assert Identity::AccessToken.exists?(token.id)
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

        assert_client_authentication_failed params.inspect
      end
    end

    assert Identity::AccessToken.exists?(token.id)
  end

  test "revocation refuses Basic beside a body client_secret" do
    token = grant_for(@client)

    revoke token.token, params: { client_secret: @secret }, headers: basic(@client.client_id, @secret)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert Identity::AccessToken.exists?(token.id)
  end

  test "metadata advertises client_secret_basic for revocation" do
    untenanted { get "/.well-known/oauth-authorization-server" }

    assert_equal %w[ none client_secret_post client_secret_basic ], response.parsed_body["revocation_endpoint_auth_methods_supported"]
  end

  private
    def grant_for(client)
      identities(:david).access_tokens.create!(oauth_client: client, permission: :read)
    end

    def revoke(token, params: {}, headers: {})
      untenanted { post oauth_revocation_path, params: { token: token }.merge(params), headers: headers }
    end
end
