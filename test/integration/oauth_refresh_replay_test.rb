require "test_helper"

# Refresh token replay (OAuth 2.1 §4.3.1, RFC 9700 §4.14.2): presenting a
# rotated refresh token again revokes the grant, unless it's a retry of the
# rotation that just happened.
class OauthRefreshReplayTest < ActionDispatch::IntegrationTest
  setup do
    @client = oauth_clients(:mcp_client)
    @grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :read)
    freeze_time
  end

  test "a retry within the grace window gets the same successor, and rotates nothing" do
    presented = @grant.refresh_token
    refresh presented
    first = response.parsed_body

    travel Oauth::RetiredRefreshToken::GRACE - 1.second
    refresh presented

    assert_response :success
    assert_equal first.slice("access_token", "refresh_token", "scope"), response.parsed_body.slice("access_token", "refresh_token", "scope")
    assert_equal first["refresh_token"], @grant.reload.refresh_token
  end

  test "a replay at the end of the grace window revokes the grant" do
    presented = @grant.refresh_token
    refresh presented
    successor = response.parsed_body

    travel Oauth::RetiredRefreshToken::GRACE
    refresh presented

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_grant_revoked successor
  end

  test "a replay long after rotation revokes the grant" do
    presented = @grant.refresh_token
    refresh presented
    successor = response.parsed_body

    travel 1.day
    refresh presented

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_grant_revoked successor
  end

  test "a replay of an older ancestor revokes the grant" do
    ancestor = @grant.refresh_token
    refresh ancestor
    travel 1.hour
    refresh response.parsed_body["refresh_token"]
    successor = response.parsed_body

    travel 1.hour
    refresh ancestor

    assert_response :bad_request
    assert_grant_revoked successor
  end

  test "a retry within the grace window after the successor has itself rotated is refused, without revoking" do
    ancestor = @grant.refresh_token
    refresh ancestor
    travel 1.second
    refresh response.parsed_body["refresh_token"]
    successor = response.parsed_body

    travel 1.second
    refresh ancestor

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert Identity::AccessToken.exists?(@grant.id)
    assert_equal successor["refresh_token"], @grant.reload.refresh_token
  end

  test "a replay asking for a scope beyond the grant still revokes it" do
    presented = @grant.refresh_token
    refresh presented
    successor = response.parsed_body

    travel 1.day
    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: presented, client_id: @client.client_id, scope: "admin" }
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_grant_revoked successor
  end

  test "a retry within the grace window weighs its scope as a live refresh would" do
    presented = @grant.refresh_token
    refresh presented
    successor = response.parsed_body

    [ "read write", "", "admin" ].each do |scope|
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: presented, client_id: @client.client_id, scope: scope }
      end

      assert_response :bad_request, scope.inspect
      assert_equal "invalid_scope", response.parsed_body["error"], scope.inspect
    end

    assert_equal successor["refresh_token"], @grant.reload.refresh_token
  end

  test "a retry within the grace window must ask for the scope the rotation produced" do
    @grant.update! permission: :write
    presented = @grant.refresh_token
    refresh presented
    successor = response.parsed_body
    assert_equal "read write", successor["scope"]

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: presented, client_id: @client.client_id, scope: "read" }
    end
    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: presented, client_id: @client.client_id, scope: "read write" }
    end
    assert_response :success
    assert_equal successor["refresh_token"], response.parsed_body["refresh_token"]
  end

  test "a successor rotated by a host whose clock runs behind still supersedes the retry" do
    ancestor = @grant.refresh_token
    refresh ancestor
    travel(-5.seconds)
    refresh response.parsed_body["refresh_token"]
    successor = response.parsed_body

    travel 10.seconds
    refresh ancestor

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_equal successor["refresh_token"], @grant.reload.refresh_token
  end

  test "a replay whose grant vanished mid-request is refused, not an error" do
    presented = @grant.refresh_token
    loser = Identity::AccessToken.find(@grant.id)
    refresh presented
    Identity::AccessToken.where(id: @grant.id).delete_all

    Identity::AccessToken.stubs(:find_by_refresh_token).returns(loser)
    refresh presented

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "another client replaying a rotated token is refused, without revoking" do
    presented = @grant.refresh_token
    refresh presented

    travel 1.day
    refresh presented, client_id: oauth_clients(:trusted_client).client_id

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert Identity::AccessToken.exists?(@grant.id)
  end

  test "a refresh that loses a concurrent rotation gets the winner's successor" do
    presented = @grant.refresh_token
    loser = Identity::AccessToken.find(@grant.id)

    refresh presented
    winner = response.parsed_body

    Identity::AccessToken.stubs(:find_by_refresh_token).returns(loser)
    refresh presented

    assert_response :success
    assert_equal winner.slice("access_token", "refresh_token"), response.parsed_body.slice("access_token", "refresh_token")
  end

  test "revoking a rotated refresh token revokes the grant" do
    presented = @grant.refresh_token
    refresh presented
    successor = response.parsed_body

    untenanted { post oauth_revocation_path, params: { token: presented, client_id: @client.client_id } }

    assert_response :success
    assert_grant_revoked successor
  end

  test "another client cannot revoke through a rotated refresh token" do
    presented = @grant.refresh_token
    refresh presented

    untenanted { post oauth_revocation_path, params: { token: presented, client_id: oauth_clients(:trusted_client).client_id } }

    assert_response :success
    assert Identity::AccessToken.exists?(@grant.id)
  end

  private
    def refresh(refresh_token, client_id: @client.client_id)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: client_id }
      end
    end

    def assert_grant_revoked(successor)
      assert_not Identity::AccessToken.exists?(@grant.id)

      refresh successor["refresh_token"]
      assert_response :bad_request
    end
end
