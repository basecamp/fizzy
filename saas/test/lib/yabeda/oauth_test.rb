require "test_helper"
require "yabeda/testing"

class Yabeda::OauthTest < ActionDispatch::IntegrationTest
  VERIFIER = "dBjftJeZ4CVP-mJ92K9OsQdq2VqrkaKUX38OaoPvBqg"
  CHALLENGE = Base64.urlsafe_encode64(Digest::SHA256.digest(VERIFIER), padding: false)
  REDIRECT_URI = "http://127.0.0.1:8888/callback"

  setup do
    Yabeda::TestAdapter.instance.reset!
    @client = oauth_clients(:mcp_client)
    @identity = identities(:david)
  end

  test "a code exchange and a refresh are token grants, and each is timed" do
    exchange authorization_code
    refresh response.parsed_body["refresh_token"]

    assert_equal 1, count(:token_grants_total, grant_type: "authorization_code", client_type: "public")
    assert_equal 1, count(:token_grants_total, grant_type: "refresh_token", client_type: "public")
    assert_operator measured(:token_request_duration_seconds, grant_type: "authorization_code"), :>, 0
    assert_operator measured(:token_request_duration_seconds, grant_type: "refresh_token"), :>, 0
  end

  test "token endpoint errors, by code and client type" do
    refresh "fizzy_rt_unknown"

    assert_equal 1, count(:token_errors_total, error_code: "invalid_grant", client_type: "public")
  end

  test "revocation endpoint errors count as token errors" do
    untenanted { post oauth_revocation_path, params: { token: "x", client_id: oauth_clients(:confidential_client).client_id } }

    assert_equal 1, count(:token_errors_total, error_code: "invalid_client", client_type: "confidential")
  end

  test "consent approved and denied" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: consent_params }
    untenanted { post oauth_authorization_path, params: consent_params(error: "access_denied") }

    assert_equal 1, count(:authorization_grants_total, client_type: "public", account_scope: "identity")
    assert_equal 1, count(:authorization_denials_total, client_type: "public")
  end

  test "revocations by a client, by token presented" do
    access = grant
    refreshable = grant
    revoke access.raw_token
    revoke refreshable.raw_refresh_token

    assert_equal 1, count(:revocations_total, token_type: "access", initiator: "client")
    assert_equal 1, count(:revocations_total, token_type: "refresh", initiator: "client")
  end

  test "revocations by a person: an app disconnected and a personal access token" do
    sign_in_as :david
    grant
    pat = @identity.access_tokens.create!(permission: :read)

    delete my_connected_app_path(@client)
    delete my_access_token_path(pat)

    assert_equal 1, count(:revocations_total, token_type: "grant", initiator: "user")
    assert_equal 1, count(:revocations_total, token_type: "access", initiator: "user")
  end

  test "a grace retry and a reuse are replays, and reuse ends the family" do
    freeze_time
    presented = grant.raw_refresh_token
    refresh presented
    refresh presented
    travel Oauth::RetiredRefreshToken::GRACE
    refresh presented

    assert_equal 1, count(:replays_total, kind: "grace")
    assert_equal 1, count(:replays_total, kind: "reuse")
    assert_equal 1, count(:family_revocations_total, reason: "reuse_detected")
    assert_equal 1, count(:token_grants_total, grant_type: "refresh_token", client_type: "public")
  end

  test "a replayed code ends the family" do
    code = authorization_code
    exchange code
    exchange code

    assert_equal 1, count(:family_revocations_total, reason: "code_replayed")
  end

  test "the idle sweep's revocations are family revocations" do
    lapsed = grant
    lapsed.update_columns updated_at: (Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.minute).ago

    Identity::AccessToken.cleanup

    assert_equal 1, count(:family_revocations_total, reason: "lapsed")
  end

  test "deleting an identity counts its grants as family revocations, and not its personal access tokens" do
    grant
    @identity.access_tokens.create!(permission: :read)
    grants = @identity.access_tokens.oauth.count

    @identity.destroy!

    assert_equal grants, count(:family_revocations_total, reason: "identity_deleted")
    assert_equal 0, Yabeda::TestAdapter.instance.counters.fetch(Yabeda.oauth.revocations_total).values.sum
  end

  test "registrations and rejections" do
    untenanted { post oauth_clients_path, as: :json, params: { redirect_uris: [ REDIRECT_URI ] } }
    untenanted { post oauth_clients_path, as: :json, params: { redirect_uris: %w[ http://example.com/callback ] } }

    assert_equal 1, count(:dcr_registrations_total)
    assert_equal 1, count(:dcr_rejections_total, reason: "invalid_redirect_uri")
  end

  test "an operator-provisioned client is no registration" do
    Oauth::Client.create!(name: "Partner", redirect_uris: %w[ https://partner.example.com/callback ])

    assert_equal 0, count(:dcr_registrations_total).to_i
  end

  test "rate limit hits, which are not errors" do
    ActiveSupport::Cache::NullStore.any_instance.stubs(:increment).returns(21)

    refresh "fizzy_rt_unknown"
    untenanted { post oauth_clients_path, as: :json, params: { redirect_uris: [ REDIRECT_URI ] } }

    assert_equal 1, count(:rate_limit_hits_total, endpoint: "tokens")
    assert_equal 1, count(:rate_limit_hits_total, endpoint: "clients")
    assert_equal 0, count(:token_errors_total, error_code: "slow_down", client_type: "public").to_i
    assert_equal 0, count(:dcr_rejections_total, reason: "slow_down").to_i
  end

  test "cleanup step failures" do
    Oauth::Client.stubs(:stale).raises(ActiveRecord::StatementInvalid, "boom")

    assert_raises(ActiveRecord::StatementInvalid) { Oauth::Client.cleanup }

    assert_equal 1, count(:cleanup_step_failures_total, step: "stale_clients")
  end

  test "no metric is labeled with a client id" do
    exchange authorization_code
    refresh "fizzy_rt_unknown"

    Yabeda::TestAdapter.instance.counters.each_value do |series|
      series.each_key { |tags| assert_not_includes tags.values.map(&:to_s), @client.client_id }
    end
  end

  private
    def count(metric, **tags)
      Yabeda::TestAdapter.instance.counters.fetch(Yabeda.oauth.public_send(metric))[tags]
    end

    def measured(metric, **tags)
      Yabeda::TestAdapter.instance.histograms.fetch(Yabeda.oauth.public_send(metric))[tags]
    end

    def grant
      @identity.access_tokens.create!(oauth_client: @client, permission: :read)
    end

    def consent_params(**overrides)
      { client_id: @client.client_id, redirect_uri: REDIRECT_URI, response_type: "code", code_challenge: CHALLENGE,
        code_challenge_method: "S256", scope: "read", state: "xyz123" }.merge(overrides)
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

    def refresh(refresh_token)
      untenanted { post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id } }
    end

    def revoke(token)
      untenanted { post oauth_revocation_path, params: { token: token, client_id: @client.client_id } }
    end
end
