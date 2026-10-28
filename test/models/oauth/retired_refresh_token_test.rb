require "test_helper"

class Oauth::RetiredRefreshTokenTest < ActiveSupport::TestCase
  setup do
    @grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
  end

  test "rotation retires the presented refresh token" do
    presented = @grant.raw_refresh_token

    assert @grant.refresh

    assert_equal [ TokenDigester.digest(presented) ], @grant.retired_refresh_tokens.pluck(:refresh_token_digest)
  end

  test "a rotation that loses the race retires nothing and leaves the winner's successor retryable" do
    presented = @grant.raw_refresh_token
    loser = Identity::AccessToken.find(@grant.id)

    assert @grant.refresh
    assert_nil loser.refresh

    assert_equal 1, Oauth::RetiredRefreshToken.count
    assert Oauth::RetiredRefreshToken.find_by_raw_token(presented).retryable?(@grant.reload)
  end

  test "revoking a grant deletes its retired refresh tokens" do
    @grant.refresh

    assert_difference "Oauth::RetiredRefreshToken.count", -1 do
      @grant.destroy
    end
  end

  test "destroying a grant locks it before deleting its retired tokens, the order rotation takes them in" do
    @grant.refresh
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }

    @grant.destroy

    ActiveSupport::Notifications.unsubscribe(subscriber)
    lock = statements.index { |sql| sql.match?(/\ASELECT \W?identity_access_tokens\W?\.\W?id\W? FROM \W?identity_access_tokens\W? WHERE/) }
    delete = statements.index { |sql| sql.match?(/\ADELETE FROM \W?oauth_retired_refresh_tokens\W?/) }
    assert lock && delete && lock < delete, statements.join("\n")
  end

  test "cleanup deletes retired tokens past retention, keeping the rest" do
    freeze_time
    @grant.refresh
    travel Oauth::RetiredRefreshToken::RETENTION - 1.day
    @grant.refresh

    travel 1.day + 1.minute
    assert_difference "Oauth::RetiredRefreshToken.count", -1 do
      Oauth::RetiredRefreshToken.cleanup
    end
  end

  test "a retired token keeps digests, and the successor pair only encrypted" do
    presented = @grant.raw_refresh_token
    @grant.refresh
    retired = @grant.retired_refresh_tokens.sole

    assert_equal TokenDigester.digest(presented), retired.refresh_token_digest
    assert_equal TokenDigester.digest(@grant.raw_refresh_token), retired.successor_refresh_token_digest
    assert_equal({ access_token: @grant.raw_token, refresh_token: @grant.raw_refresh_token }, retired.successor)

    [ presented, @grant.raw_token, @grant.raw_refresh_token ].each do |raw|
      assert_not_includes retired.successor_payload, raw
    end
  end

  test "the successor pair can't be read once the grace window has passed" do
    @grant.refresh
    retired = @grant.retired_refresh_tokens.sole

    travel Oauth::RetiredRefreshToken::GRACE - 1.second
    assert_not_nil retired.successor

    travel 2.seconds
    assert_nil retired.successor
  end

  test "forget_successors blanks pairs whose grace window has passed" do
    @grant.refresh
    retired = @grant.retired_refresh_tokens.sole

    Oauth::RetiredRefreshToken.forget_successors
    assert_not_nil retired.reload.successor_payload

    travel Oauth::RetiredRefreshToken::GRACE + 1.second
    Oauth::RetiredRefreshToken.forget_successors
    assert_nil retired.reload.successor_payload
  end

  test "superseded compares the grant's current refresh digest with the successor's" do
    @grant.refresh
    retired = @grant.retired_refresh_tokens.sole

    assert_not retired.superseded?(Identity::AccessToken.find(@grant.id))

    @grant.refresh
    assert retired.superseded?(Identity::AccessToken.find(@grant.id))
  end

  test "a tampered successor payload reads as none" do
    @grant.refresh
    retired = @grant.retired_refresh_tokens.sole
    retired.successor_payload = retired.successor_payload.reverse

    assert_nil retired.successor
  end
end
