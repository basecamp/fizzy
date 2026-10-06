require "test_helper"

class Oauth::RetiredRefreshTokenTest < ActiveSupport::TestCase
  setup do
    @grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client))
  end

  test "rotation retires the presented refresh token" do
    presented = @grant.refresh_token

    assert @grant.refresh

    assert_equal [ presented ], @grant.retired_refresh_tokens.pluck(:refresh_token)
  end

  test "a rotation that loses the race retires nothing and leaves the winner's successor retryable" do
    presented = @grant.refresh_token
    loser = Identity::AccessToken.find(@grant.id)

    assert @grant.refresh
    assert_nil loser.refresh

    assert_equal 1, Oauth::RetiredRefreshToken.count
    assert Oauth::RetiredRefreshToken.find_by(refresh_token: presented).retryable?
  end

  test "revoking a grant deletes its retired refresh tokens" do
    @grant.refresh

    assert_difference "Oauth::RetiredRefreshToken.count", -1 do
      @grant.destroy
    end
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
end
