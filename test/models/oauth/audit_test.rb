require "test_helper"

# Grants and clients ended outside any request: the sweeps, and cascades from
# deleting an identity or a client. Every ending reports an event.
class Oauth::AuditTest < ActiveSupport::TestCase
  include OauthAuditTestHelper

  setup do
    @client = oauth_clients(:mcp_client)
    @identity = identities(:david)
  end

  test "a refresh rolled back by its caller reports nothing, and a committed one reports once" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :write)

    events = capture_oauth_events do
      Identity::AccessToken.transaction do
        assert grant.refresh(permission: "read")
        raise ActiveRecord::Rollback
      end
    end
    assert_empty events

    events = capture_oauth_events { assert grant.reload.refresh(permission: "read") }
    assert_equal %w[ oauth.token.refreshed oauth.grant.narrowed ], oauth_event_names(events)
  end

  test "the idle sweep revokes a lapsed grant" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)
    grant.update_columns updated_at: (Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.minute).ago

    events = capture_oauth_events { Identity::AccessToken.cleanup }

    revoked = oauth_event(events, "oauth.grant.revoked")
    assert_equal grant.id, revoked[:grant_id]
    assert_equal "lapsed", revoked[:reason]
    assert_equal "system", revoked[:actor]
    assert_nil revoked[:request_id]
    assert_no_secrets_in events, grant.raw_token, grant.raw_refresh_token
  end

  test "the client sweep reports each client it removes" do
    client = Oauth::Client.create!(name: "Abandoned", redirect_uris: %w[ http://127.0.0.1:9999/callback ], dynamically_registered: true)
    client.update_columns updated_at: (Oauth::Client::UNUSED_RETENTION + 1.day).ago

    events = capture_oauth_events { Oauth::Client.cleanup }

    swept = oauth_event(events, "oauth.client.swept")
    assert_equal client.client_id, swept[:client_id]
    assert_equal "unused", swept[:reason]
    assert_equal "system", swept[:actor]
  end

  test "a client the sweep spares reports nothing" do
    assert_empty capture_oauth_events { @client.destroy_if_still_unused }
  end

  test "deleting an identity revokes its grants and personal access tokens" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)
    pat = @identity.access_tokens.create!(permission: :read)
    ids = @identity.access_tokens.ids

    events = capture_oauth_events { @identity.destroy! }

    ended = events.select { |event| event[:name].in?(%w[ oauth.grant.revoked oauth.pat.revoked ]) }
    assert_equal ids.sort, ended.map { |event| event[:payload][:grant_id] }.sort
    assert_includes ids, grant.id
    assert_includes ids, pat.id
    ended.each { |event| assert_equal "identity_deleted", event[:payload][:reason] }
  end

  test "deleting a client revokes its grants" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)

    events = capture_oauth_events { @client.destroy! }

    revoked = oauth_event(events, "oauth.grant.revoked")
    assert_equal grant.id, revoked[:grant_id]
    assert_equal "client_deleted", revoked[:reason]
    assert_equal @client.client_id, revoked[:client_id]
  end

  test "a grant ended with no reason given still reports one" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)

    events = capture_oauth_events { grant.destroy! }

    assert_equal "deleted", oauth_event(events, "oauth.grant.revoked")[:reason]
  end

  test "an operator-provisioned client is registered by an admin" do
    events = capture_oauth_events do
      Oauth::Client.create!(name: "Partner", redirect_uris: %w[ https://partner.example.com/callback ])
    end

    registered = oauth_event(events, "oauth.client.registered")
    assert_equal "partner", registered[:client_class]
    assert_equal "admin", registered[:actor]
  end

  test "a trusted client is first party" do
    grant = @identity.access_tokens.create!(oauth_client: oauth_clients(:trusted_client), permission: :read)

    events = capture_oauth_events { grant.revoke reason: "disconnected", actor: "user" }

    assert_equal "first_party", oauth_event(events, "oauth.grant.revoked")[:client_class]
  end

  test "a rolled-back revocation reports nothing" do
    grant = @identity.access_tokens.create!(oauth_client: @client, permission: :read)

    events = capture_oauth_events do
      Identity::AccessToken.transaction do
        grant.revoke reason: "disconnected", actor: "user"
        raise ActiveRecord::Rollback
      end
    end

    assert_empty events
    assert Identity::AccessToken.exists?(grant.id)
  end

  test "an unknown actor is refused" do
    assert_raises(ArgumentError) { Oauth::Audit.record "grant.revoked", actor: "someone" }
  end

  test "a failed cleanup step is announced and still fails" do
    failures = []
    callback = ->(event) { failures << event.payload }

    Identity::AccessToken.stubs(:lapsed).raises(ActiveRecord::StatementInvalid, "boom")

    ActiveSupport::Notifications.subscribed(callback, "cleanup_failure.oauth") do
      assert_raises(ActiveRecord::StatementInvalid) { Identity::AccessToken.cleanup }
    end

    assert_equal [ { step: :lapsed_grants, error_class: "ActiveRecord::StatementInvalid" } ], failures
  end

  test "each sweep is a named cleanup step" do
    steps = []
    Oauth.stubs(:cleanup_step).with { |step| steps << step }

    Identity::AccessToken.cleanup
    Oauth::Client.cleanup
    Oauth::RetiredRefreshToken.cleanup
    Oauth::RetiredRefreshToken.forget_successors

    assert_equal %i[ lapsed_grants stale_clients retired_refresh_tokens refresh_successors ], steps
  end
end
