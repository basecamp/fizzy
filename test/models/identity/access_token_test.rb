require "test_helper"

class Identity::AccessTokenTest < ActiveSupport::TestCase
  test "oauth tokens expire and get refresh tokens on create" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_not_nil token.raw_refresh_token
    assert_in_delta Identity::AccessToken::EXPIRES_IN.from_now, token.expires_at, 5.seconds
  end

  test "personal tokens don't expire and get no refresh token" do
    token = identities(:david).access_tokens.create!(description: "Personal")

    assert_nil token.raw_refresh_token
    assert_nil token.expires_at
    assert_not token.expired?
  end

  test "new tokens carry a prefix naming their kind" do
    personal = identities(:david).access_tokens.create!(description: "Personal")
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_match(/\Afizzy_pat_[1-9A-HJ-NP-Za-km-z]{44}\z/, personal.raw_token)
    assert_match(/\Afizzy_at_[1-9A-HJ-NP-Za-km-z]{44}\z/, grant.raw_token)
    assert_match(/\Afizzy_rt_[1-9A-HJ-NP-Za-km-z]{44}\z/, grant.raw_refresh_token)
  end

  test "a rotation issues prefixed tokens, even for a grant issued before prefixes" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client),
      raw_token: "legacyAccessToken0123456789", raw_refresh_token: "legacyRefreshToken0123456789")

    assert grant.refresh

    assert grant.raw_token.start_with?("fizzy_at_")
    assert grant.raw_refresh_token.start_with?("fizzy_rt_")
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
    old_token, old_refresh_token = token.raw_token, token.raw_refresh_token

    travel Identity::AccessToken::EXPIRES_IN + 1.minute do
      assert token.refresh

      assert_not_equal old_token, token.raw_token
      assert_not_equal old_refresh_token, token.raw_refresh_token
      assert_not token.expired?
    end
  end

  test "refresh fails when the presented refresh token was already rotated" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    stale = Identity::AccessToken.find(token.id)

    assert token.refresh
    winner = token.token_digest

    assert_not stale.refresh
    assert_equal winner, token.reload.token_digest
  end

  test "active scope excludes expired tokens" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_includes Identity::AccessToken.active, token
    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      assert_not_includes Identity::AccessToken.active, token
      assert_includes Identity::AccessToken.active, identity_access_tokens(:davids_api_token)
    end
  end

  test "find_honored rejects expired tokens" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)

    assert_equal token, Identity::AccessToken.find_honored(token.raw_token)
    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      assert_nil Identity::AccessToken.find_honored(token.raw_token)
    end
  end

  test "find_honored returns a read-only token and leaves the method check to the caller" do
    token = identity_access_tokens(:jasons_api_token)

    assert_equal token, Identity::AccessToken.find_honored(token.raw_token)
    assert_not token.allows?("POST")
  end

  test "find_honored rejects unknown tokens" do
    assert_nil Identity::AccessToken.find_honored("nonsense")
  end

  test "the idle limit is a fixed span of seconds, whatever the zone's daylight saving" do
    travel_to Time.utc(2026, 12, 1, 12) do
      cutoff = Time.current - Identity::AccessToken::REFRESH_IDLE_LIMIT.to_i
      grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
      grant.update_columns updated_at: cutoff - 30.minutes

      Time.use_zone("America/New_York") do
        assert grant.lapsed?
        assert_includes Identity::AccessToken.lapsed, grant
        assert_not_includes Identity::AccessToken.unlapsed, grant
      end
    end
  end

  test "a personal access token stores only its digest" do
    token = identities(:david).access_tokens.create!(description: "Personal")
    raw_token = token.raw_token
    token.reload

    assert_equal TokenDigester.digest(raw_token), token.token_digest
    assert_nil token.refresh_token_digest
  end

  test "an OAuth grant stores only digests of its tokens" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    raw_token, raw_refresh_token = grant.raw_token, grant.raw_refresh_token
    grant.reload

    assert_equal TokenDigester.digest(raw_token), grant.token_digest
    assert_equal TokenDigester.digest(raw_refresh_token), grant.refresh_token_digest
    assert_nil grant.raw_token
  end

  test "rotation stores only digests of the new tokens" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    grant.refresh
    raw_token, raw_refresh_token = grant.raw_token, grant.raw_refresh_token
    grant.reload

    assert_equal TokenDigester.digest(raw_token), grant.token_digest
    assert_equal TokenDigester.digest(raw_refresh_token), grant.refresh_token_digest
  end

  test "tokens are found by digest" do
    personal = identities(:david).access_tokens.create!(description: "Personal")
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))

    assert_equal personal, Identity::AccessToken.find_by_raw_token(personal.raw_token)
    assert_equal grant, Identity::AccessToken.find_by_raw_token(grant.raw_token)
    assert_equal grant, Identity::AccessToken.find_by_refresh_token(grant.raw_refresh_token)

    assert_nil Identity::AccessToken.find_by_raw_token(grant.raw_refresh_token)
    assert_nil Identity::AccessToken.find_by_raw_token(grant.token_digest)
    assert_nil Identity::AccessToken.find_by_raw_token("")
    assert_nil Identity::AccessToken.find_by_raw_token(nil)
  end

  test "a lookup by digest never reads plaintext" do
    personal = identities(:david).access_tokens.create!(description: "Personal")
    statements = capture_sql { Identity::AccessToken.find_honored(personal.raw_token) }

    assert statements.any? { |sql| sql.include?("token_digest") }, statements.join("\n")
    assert statements.none? { |sql| sql.match?(/\Wtoken\W*=/) }, statements.join("\n")
  end

  test "no token is stored in plaintext" do
    assert_not_includes Identity::AccessToken.column_names, "token"
  end

  # Dropped beside `token` only once every process runs code that ignores it.
  test "the plaintext refresh token column is ignored" do
    assert_not_includes Identity::AccessToken.column_names, "refresh_token"
    assert_not Identity::AccessToken.new.respond_to?(:refresh_token)
  end

  test "two tokens can't share a digest" do
    token = identities(:david).access_tokens.create!(description: "Personal")

    assert_raises ActiveRecord::RecordNotUnique do
      identities(:kevin).access_tokens.create!(description: "Copy", raw_token: token.raw_token)
    end

    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    assert_raises ActiveRecord::RecordNotUnique do
      identities(:kevin).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), raw_refresh_token: grant.raw_refresh_token)
    end
  end

  private
    def capture_sql(&block)
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }
      block.call
      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
