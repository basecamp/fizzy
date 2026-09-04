require "test_helper"

class Identity::AccessTokenTest < ActiveSupport::TestCase
  test "oauth tokens expire and get refresh tokens on create" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_not_nil token.refresh_token
    assert_in_delta Identity::AccessToken::EXPIRES_IN.from_now, token.expires_at, 5.seconds
  end

  test "personal tokens don't expire and get no refresh token" do
    token = identities(:david).access_tokens.create!(description: "Personal")

    assert_nil token.refresh_token
    assert_nil token.expires_at
    assert_not token.expired?
  end

  test "expired?" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_not token.expired?
    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      assert token.expired?
    end
  end

  test "refresh rotates both tokens and extends expiry" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    old_token, old_refresh_token = token.token, token.refresh_token

    travel Identity::AccessToken::EXPIRES_IN + 1.minute do
      assert token.refresh

      assert_not_equal old_token, token.token
      assert_not_equal old_refresh_token, token.refresh_token
      assert_not token.expired?
    end
  end

  test "refresh fails when the presented refresh token was already rotated" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    stale = Identity::AccessToken.find(token.id)

    assert token.refresh
    assert_not stale.refresh
    assert_equal token.reload.token, token.token
  end

  test "active scope excludes expired tokens" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_includes Identity::AccessToken.active, token
    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      assert_not_includes Identity::AccessToken.active, token
      assert_includes Identity::AccessToken.active, identity_access_tokens(:davids_api_token)
    end
  end

  test "find_by_permissable_access_token rejects expired tokens" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)

    assert_equal identities(:david), Identity.find_by_permissable_access_token(token.token, method: "GET")
    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      assert_nil Identity.find_by_permissable_access_token(token.token, method: "GET")
    end
  end
end
