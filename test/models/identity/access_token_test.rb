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

  test "a replayed code's grants are read under a row lock, so concurrent replays revoke each once" do
    code = Data.define(:jti).new(jti: SecureRandom.uuid)

    assert Identity::AccessToken.minted_by(code).lock_value
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

    assert_equal token, Identity::AccessToken.find_honored(token.token)
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

  test "a personal access token is stored digested and, for now, in plaintext" do
    token = identities(:david).access_tokens.create!(description: "Personal").reload

    assert_equal TokenDigester.digest(token.token), token.token_digest
    assert_nil token.refresh_token_digest
  end

  test "an OAuth grant stores only digests of its tokens" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    raw_token, raw_refresh_token = grant.raw_token, grant.raw_refresh_token
    grant.reload

    assert_nil grant.token
    assert_equal TokenDigester.digest(raw_token), grant.token_digest
    assert_equal TokenDigester.digest(raw_refresh_token), grant.refresh_token_digest
    assert_nil grant.raw_token
  end

  test "rotation stores only digests of the new tokens" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    grant.refresh
    raw_token, raw_refresh_token = grant.raw_token, grant.raw_refresh_token
    grant.reload

    assert_nil grant.token
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

  # Production code that predates digests writes personal access tokens in
  # plaintext only. Such a token still authenticates, and gets its digest the
  # first time it's used, without moving its updated_at.
  test "a personal access token without a digest is found by plaintext and digested" do
    token = undigested_personal_token("legacyPersonalToken0123456789")
    updated_at = token.updated_at

    travel 1.day do
      assert_equal token, Identity::AccessToken.find_honored("legacyPersonalToken0123456789")
    end

    token.reload
    assert_equal TokenDigester.digest("legacyPersonalToken0123456789"), token.token_digest
    assert_equal updated_at, token.updated_at

    statements = capture_sql { Identity::AccessToken.find_honored("legacyPersonalToken0123456789") }
    assert statements.none? { |sql| sql.match?(/\Wtoken\W*=/) }, statements.join("\n")
  end

  # SaaS reads GET requests from the replica, where writes are refused.
  test "a personal access token without a digest is digested when found from the replica" do
    token = undigested_personal_token("legacyPersonalToken0123456789")

    found = ApplicationRecord.with_reading_role do
      Identity::AccessToken.find_honored("legacyPersonalToken0123456789")
    end

    assert_equal token, found
    assert_equal TokenDigester.digest("legacyPersonalToken0123456789"), token.reload.token_digest
  end

  # Non-primary datacenters read local replicas and can't reach the primary.
  test "a personal access token without a digest authenticates outside the primary datacenter, undigested" do
    token = undigested_personal_token("legacyPersonalToken0123456789")
    Deployment::DatabaseResolver.stubs(:in_primary_datacenter?).returns(false)

    statements = capture_sql { assert_equal token, Identity::AccessToken.find_honored("legacyPersonalToken0123456789") }

    assert statements.none? { |sql| sql.match?(/\AUPDATE/i) }, statements.join("\n")
    assert_nil token.reload.token_digest
  end

  # Code that stores only plaintext issues prefixed personal access tokens too.
  test "a prefixed personal access token without a digest is found by plaintext and digested" do
    token = undigested_personal_token("fizzy_pat_#{"x" * 24}")

    assert_equal token, Identity::AccessToken.find_honored("fizzy_pat_#{"x" * 24}")
    assert_equal TokenDigester.digest("fizzy_pat_#{"x" * 24}"), token.reload.token_digest
  end

  # MySQL's collation matches `token` case-insensitively.
  test "a differently cased token neither authenticates nor digests the one it resembles" do
    token = undigested_personal_token("legacyPersonalToken0123456789")

    assert_nil Identity::AccessToken.find_honored("LEGACYPERSONALTOKEN0123456789")
    assert_nil token.reload.token_digest

    assert_equal token, Identity::AccessToken.find_honored("legacyPersonalToken0123456789")
    assert_equal TokenDigester.digest("legacyPersonalToken0123456789"), token.reload.token_digest
  end

  test "only personal access tokens fall back to plaintext" do
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
    grant.update_columns token: "legacyAccessToken0123456789", token_digest: nil

    assert_nil Identity::AccessToken.find_by_raw_token("legacyAccessToken0123456789")
  end

  test "the fallback stays within the scope it's called on" do
    undigested_personal_token("legacyPersonalToken0123456789")

    assert_nil Identity::AccessToken.oauth.find_by_raw_token("legacyPersonalToken0123456789")
    assert_nil Identity::AccessToken.where(identity: identities(:kevin)).find_by_raw_token("legacyPersonalToken0123456789")
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
    def undigested_personal_token(raw)
      identities(:david).access_tokens.create!(description: "Before digests").tap do |token|
        token.update_columns token: raw, token_digest: nil
      end
    end

    def capture_sql(&block)
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }
      block.call
      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
