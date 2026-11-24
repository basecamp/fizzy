require "test_helper"

class Oauth::ClientMetadata::ResolverTest < ActiveSupport::TestCase
  include OauthAuditTestHelper, OauthAvailabilityTestHelper, FetchLeaseTestHelper

  URL = "https://claude.ai/oauth/mcp-oauth-client-metadata"
  CALLBACK = "https://claude.ai/api/mcp/auth_callback"

  OPEN_URL = "https://tools.example.com/client.json"
  OPEN_CALLBACK = "https://tools.example.com/callback"

  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_dns_resolution("160.79.104.10")
  end

  test "reading fetches into an unsaved client and persists nothing" do
    stub_document

    resolution = resolve(persist: false)

    assert resolution.success?
    assert resolution.client.new_record?
    assert resolution.client.metadata_document?
    assert_equal "Claude", resolution.client.name
    assert_nil Oauth::Client.find_presented(URL)
  end

  test "intake records the registration as the client's own act" do
    stub_document

    events = capture_oauth_events { resolve(persist: true) }

    assert_equal "client", oauth_event(events, "oauth.client.registered")[:actor]
  end

  test "intake provisions a public, untrusted client from the document" do
    stub_document(etag: %("v1"))

    client = resolve(persist: true).client

    assert client.persisted?
    assert_equal URL, client.client_id
    assert client.metadata_document?
    assert_not client.trusted?
    assert_not client.dynamically_registered?
    assert_not client.confidential?
    assert_equal [ CALLBACK ], client.redirect_uris
    assert_equal %w[ read write ], client.scopes
    assert_equal %("v1"), client.metadata_etag
    assert client.metadata_expires_at.future?
  end

  test "a fresh row answers without fetching" do
    stub = stub_document
    resolve(persist: true)

    assert resolve(persist: true).success?
    assert resolve(persist: false).success?
    assert_requested stub, times: 1
  end

  test "a stale row is fetched again and updated" do
    stub_document
    client = resolve(persist: true).client
    client.update!(metadata_expires_at: 1.minute.ago)

    stub_document(client_name: "Claude (renamed)")

    assert_equal "Claude (renamed)", resolve(persist: true).client.name
    assert_equal "Claude (renamed)", client.reload.name
  end

  test "a 304 revalidates a stale row without touching its document" do
    stub_document(etag: %("v1"))
    client = resolve(persist: true).client
    client.update!(metadata_expires_at: 1.minute.ago)
    fetched_at = client.metadata_fetched_at

    stub_request(:get, URL).with(headers: { "If-None-Match" => %("v1") }).to_return(status: 304)

    assert resolve(persist: true).success?
    assert client.reload.metadata_expires_at.future?
    assert_equal fetched_at, client.metadata_fetched_at
  end

  test "while open registration is off, never fetches from a host that isn't allowlisted" do
    fetcher = Oauth::ClientMetadata::Fetcher.new
    fetcher.expects(:fetch).never

    with_oauth_config(cimd_open_registration: false) do
      [ true, false ].each do |persist|
        resolution = Oauth::ClientMetadata::Resolver.new(OPEN_URL, requester: identities(:david), fetcher: fetcher).resolve(persist: persist)

        assert_equal :unrecognized_host, resolution.outcome
        assert_equal "Unknown client", resolution.error_description
      end
    end
  end

  test "while open registration is off, a client already provisioned from a host that isn't allowlisted is unknown" do
    stub_open_document
    assert resolve_open(persist: true).success?

    with_oauth_config(cimd_open_registration: false) do
      assert_equal :unrecognized_host, resolve_open(persist: true).outcome
      assert_equal :unrecognized_host, resolve_open(persist: false).outcome
    end
  end

  test "while open registration is off, allowlisted hosts resolve and spend the same budgets" do
    with_memory_cache do
      with_oauth_config(cimd_open_registration: false) do
        stub_document

        assert resolve(persist: true).success?
        assert_equal 1, Rails.cache.read("oauth:client_metadata:#{identities(:david).id}:host:claude.ai", raw: true).to_i
        assert_equal 1, Rails.cache.read("oauth:client_metadata:#{identities(:david).id}:url:#{Digest::SHA256.hexdigest(URL)}", raw: true).to_i
      end
    end
  end

  test "a host that isn't allowlisted, or only looks like one that is, is the open tier" do
    [ "https://claude.ai.example.com/client.json", "https://evil-claude.ai/client.json", "https://CLAUDE.AI/client.json",
      "https://Claude.ai/client.json", "https://www.claude.ai/client.json", OPEN_URL ].each do |url|
      assert_equal :open, Oauth::ClientMetadata.tier(url), url
    end

    assert_equal :recognized, Oauth::ClientMetadata.tier(URL)
  end

  test "the open tier provisions a client" do
    stub_open_document

    events = []
    ActiveSupport::Notifications.subscribed(->(event) { events << event.payload }, "cimd_client_created.oauth") do
      assert resolve_open(persist: true).client.persisted?
    end

    assert_equal [ { tier: :open } ], events
  end

  test "losing an open-tier creation race adopts the winner" do
    stub_open_document
    winner = Oauth::Client.create!(client_id: OPEN_URL, name: "Tools", redirect_uris: [ OPEN_CALLBACK ], client_id_metadata_document: true)
    Oauth::Client.stubs(:find_presented).returns(nil).then.returns(winner)

    assert_equal winner, resolve_open(persist: true).client
  end

  test "open-tier fetches are limited per registrable domain, across everyone" do
    with_memory_cache do
      Oauth::ClientMetadata::Fetcher.any_instance.stubs(:fetch).returns(Oauth::ClientMetadata::Fetcher::Result.failure(:connection_failed))
      people = identities(:david, :kevin)

      outcomes = Array.new(Oauth::ClientMetadata::Resolver::DOMAIN_ATTEMPT_LIMIT + 1) do |index|
        Oauth::ClientMetadata::Resolver.resolve_for_read("https://tools#{index}.example.com/client.json", requester: people[index % 2]).outcome
      end

      assert_equal [ :fetch_failed ] * Oauth::ClientMetadata::Resolver::DOMAIN_ATTEMPT_LIMIT + [ :throttled ], outcomes
      assert_equal Oauth::ClientMetadata::Resolver::DOMAIN_ATTEMPT_LIMIT + 1,
        Rails.cache.read("oauth:client_metadata:domain:example.com", raw: true).to_i
      assert_equal :throttled, Oauth::ClientMetadata::Resolver.resolve_for_read("https://other.example.com/client.json", requester: identities(:jz)).outcome
    end
  end

  test "an open-tier client already provisioned resolves past its domain's spent budget" do
    with_memory_cache do
      stub_open_document
      client = resolve_open(persist: true).client
      client.update!(metadata_expires_at: 1.minute.ago)
      Rails.cache.write("oauth:client_metadata:domain:example.com", Oauth::ClientMetadata::Resolver::DOMAIN_ATTEMPT_LIMIT, raw: true, expires_in: 1.hour)

      events = capture_refusals { assert_equal client, resolve_open(persist: true).client }

      assert_empty events, "serving a stored document is no refusal"
    end
  end

  test "a new open-tier client refused for its domain's budget is counted as a refusal" do
    with_memory_cache do
      Rails.cache.write("oauth:client_metadata:domain:example.com", Oauth::ClientMetadata::Resolver::DOMAIN_ATTEMPT_LIMIT, raw: true, expires_in: 1.hour)

      events = capture_refusals { assert_equal :throttled, resolve_open(persist: true).outcome }

      assert_equal [ { reason: :budget, tier: :open } ], events
    end
  end

  test "a blocked domain is an unknown client before any fetch, across its hosts and in either tier" do
    fetcher = Oauth::ClientMetadata::Fetcher.new
    fetcher.expects(:fetch).never

    with_oauth_config(cimd_blocked_domains: %w[ EXAMPLE.com claude.ai ]) do
      [ OPEN_URL, "https://example.com/client.json", "https://a.b.Example.COM/client.json", URL ].each do |url|
        [ true, false ].each do |persist|
          resolution = Oauth::ClientMetadata::Resolver.new(url, requester: identities(:david), fetcher: fetcher).resolve(persist: persist)

          assert_equal :blocked_domain, resolution.outcome, url
          assert_equal "Unknown client", resolution.error_description
        end
      end
    end
  end

  test "a blocked domain's clients already provisioned stop resolving" do
    stub_open_document
    assert resolve_open(persist: true).success?

    with_oauth_config(cimd_blocked_domains: %w[ example.com ]) do
      events = capture_refusals do
        assert_equal :blocked_domain, resolve_open(persist: true).outcome
        assert_equal :blocked_domain, resolve_open(persist: false).outcome
      end

      assert_equal [ { reason: :blocked_domain, tier: :open } ] * 2, events
    end
  end

  test "a block covers its own host and what's under it, at a label boundary" do
    with_oauth_config(cimd_blocked_domains: %w[ tools.example.com ]) do
      assert Oauth::ClientMetadata.blocked?("https://tools.example.com/client.json")
      assert Oauth::ClientMetadata.blocked?("https://eu.tools.example.com/client.json")
      assert_not Oauth::ClientMetadata.blocked?("https://example.com/client.json")
      assert_not Oauth::ClientMetadata.blocked?("https://other.example.com/client.json")
      assert_not Oauth::ClientMetadata.blocked?("https://mytools.example.com/client.json")
      assert_not Oauth::ClientMetadata.blocked?("https://tools.example.com.evil.test/client.json")
      assert Oauth::ClientMetadata.blocked?("https://tools.example.com./client.json"), "a trailing dot names the same host"
      assert Oauth::ClientMetadata.blocked?("https://eu.tools.example.com./client.json")
    end

    with_oauth_config(cimd_blocked_domains: %w[ example.com. ]) do
      assert Oauth::ClientMetadata.blocked?("https://tools.example.com/client.json")
    end

    assert_not Oauth::ClientMetadata.blocked?(OPEN_URL), "nothing is blocked unless configured"
  end

  test "someone holding grants to as many open-tier apps as the cap allows is refused another, before any fetch" do
    connect_open_tier_apps identities(:david), Oauth::ClientMetadata::GRANT_CAP
    fetcher = Oauth::ClientMetadata::Fetcher.new
    fetcher.expects(:fetch).never

    events = capture_refusals do
      [ true, false ].each do |persist|
        resolution = Oauth::ClientMetadata::Resolver.new(OPEN_URL, requester: identities(:david), fetcher: fetcher).resolve(persist: persist)

        assert_equal :grant_cap, resolution.outcome
        assert_equal Oauth::ClientMetadata::Resolver::GRANT_CAP_DESCRIPTION, resolution.error_description
      end
    end

    assert_equal [ { reason: :grant_cap, tier: :open } ] * 2, events
    assert_nil Oauth::Client.find_presented(OPEN_URL)
  end

  test "the grant cap refuses an app someone else already provisioned" do
    stub_open_document
    assert resolve_open(persist: true, requester: identities(:kevin)).success?
    connect_open_tier_apps identities(:david), Oauth::ClientMetadata::GRANT_CAP

    assert_equal :grant_cap, resolve_open(persist: true).outcome
  end

  test "the grant cap never refuses authorizing an app already connected again" do
    stub_open_document
    client = resolve_open(persist: true).client
    identities(:david).access_tokens.create!(oauth_client: client)
    connect_open_tier_apps identities(:david), Oauth::ClientMetadata::GRANT_CAP - 1

    assert_equal client, resolve_open(persist: true).client
  end

  test "an app already connected is authorized again even past the cap" do
    stub_open_document
    client = resolve_open(persist: true).client
    identities(:david).access_tokens.create!(oauth_client: client)
    connect_open_tier_apps identities(:david), Oauth::ClientMetadata::GRANT_CAP

    assert_equal client, resolve_open(persist: true).client
    assert_equal :grant_cap, Oauth::ClientMetadata::Resolver.resolve_for_intake("https://another.example.net/client.json", requester: identities(:david)).outcome
  end

  test "the grant cap counts live grants to open-tier apps, and nothing else" do
    stub_open_document
    david = identities(:david)
    connect_open_tier_apps david, Oauth::ClientMetadata::GRANT_CAP - 1

    # A second grant to an app already counted, a grant to an allowlisted app,
    # one that lapsed, one revoked, and someone else's.
    david.access_tokens.create!(oauth_client: Oauth::Client.metadata_documents.first)
    david.access_tokens.create!(oauth_client: Oauth::Client.create!(client_id: URL, name: "Claude", redirect_uris: [ CALLBACK ], client_id_metadata_document: true))
    lapsed, revoked = connect_open_tier_apps(david, 2, prefix: "gone")
    lapsed.update_columns updated_at: (Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.day).ago
    revoked.revoke(reason: "test", actor: "user")
    connect_open_tier_apps identities(:kevin), 1, prefix: "kevins"

    assert resolve_open(persist: true).success?

    connect_open_tier_apps david, 1, prefix: "last"
    assert_equal :grant_cap, Oauth::ClientMetadata::Resolver.resolve_for_intake("https://another.example.net/client.json", requester: david).outcome
  end

  test "the grant cap leaves the recognized tier, and a denial, alone" do
    stub_document
    stub_open_document
    connect_open_tier_apps identities(:david), Oauth::ClientMetadata::GRANT_CAP

    assert resolve(persist: true).success?
    assert Oauth::ClientMetadata::Resolver.resolve_for_read(OPEN_URL, requester: identities(:david), consenting: false).success?
  end

  test "a refusal is logged with its domain, and counted without it" do
    logged = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logged)
    connect_open_tier_apps identities(:david), Oauth::ClientMetadata::GRANT_CAP

    resolve_open(persist: true)

    assert_match "[Oauth::ClientMetadata] refused reason=grant_cap tier=open domain=example.com identity=#{identities(:david).id}", logged.string
  ensure
    Rails.logger = original_logger
  end

  test "telemetry that raises never costs a refusal its answer" do
    with_raising_subscriber("cimd_refusal.oauth") do
      with_oauth_config(cimd_blocked_domains: %w[ example.com ]) do
        assert_equal :blocked_domain, resolve_open(persist: true).outcome
      end
    end
  end

  test "telemetry that raises never costs a fetch or a creation its answer" do
    stub_open_document

    with_raising_subscriber("cimd_fetch.oauth", "cimd_client_created.oauth") do
      assert resolve_open(persist: true).client.persisted?
    end
  end

  test "telemetry that raises never costs a lost admission its refund and its 503" do
    with_memory_cache do
      Oauth::ClientMetadata::Fetcher.any_instance.stubs(:fetch).returns(Oauth::ClientMetadata::Fetcher::Result.failure(:overloaded))

      with_raising_subscriber("cimd_fetch.oauth") do
        assert_equal :overloaded, resolve_open(persist: true).outcome
      end

      assert_equal 0, Rails.cache.read("oauth:client_metadata:domain:example.com", raw: true).to_i
    end
  end

  test "the bulkhead and the lease refusing are counted as refusals" do
    Oauth::ClientMetadata::Fetcher::Bulkhead.stubs(:saturated?).returns(true)
    events = capture_refusals { assert_equal :overloaded, resolve_open(persist: true).outcome }
    assert_equal [ { reason: :bulkhead, tier: :open } ], events

    Oauth::ClientMetadata::Fetcher::Bulkhead.unstub(:saturated?)
    Oauth::ClientMetadata::Fetcher.any_instance.stubs(:fetch).returns(Oauth::ClientMetadata::Fetcher::Result.failure(:overloaded))
    events = capture_refusals { assert_equal :overloaded, resolve(persist: true).outcome }
    assert_equal [ { reason: :bulkhead, tier: :recognized } ], events

    Oauth::ClientMetadata::FetchLease.stubs(:acquire).returns(nil)
    events = with_oauth_config(cimd_fetch_lease: true) do
      capture_refusals { assert_equal :overloaded, resolve_open(persist: true).outcome }
    end
    assert_equal [ { reason: :lease, tier: :open } ], events
  end

  test "an open-tier URL is refused where the fetcher refuses it" do
    [ "10.0.0.1", "127.0.0.1", "169.254.169.254", "192.168.1.1", "::1" ].each do |address|
      stub_dns_resolution(address)
      stub = stub_request(:get, OPEN_URL)

      assert_equal :fetch_failed, resolve_open(persist: true).outcome, address
      assert_not_requested stub
    end

    stub_dns_resolution("93.184.216.34")
    stub_request(:get, OPEN_URL).to_return(status: 302, headers: { location: "https://169.254.169.254/latest/meta-data" })
    assert_equal :fetch_failed, resolve_open(persist: true).outcome

    assert_equal :invalid_url, Oauth::ClientMetadata::Resolver.resolve_for_intake("http://tools.example.com/client.json", requester: identities(:david)).outcome
    assert_nil Oauth::Client.find_presented(OPEN_URL)
  end

  test "a fetch the lease refuses is server pressure, and spends no budget" do
    with_memory_cache do
      Oauth::ClientMetadata::FetchLease.stubs(:acquire).returns(nil)
      fetcher = Oauth::ClientMetadata::Fetcher.new
      fetcher.expects(:fetch).never

      resolution = with_oauth_config(cimd_fetch_lease: true) do
        Oauth::ClientMetadata::Resolver.new(OPEN_URL, requester: identities(:david), fetcher: fetcher).resolve(persist: true)
      end

      assert_equal :overloaded, resolution.outcome
      assert_nil Rails.cache.read("oauth:client_metadata:domain:example.com", raw: true)
    end
  end

  test "the lease is held for the fetch and released before the client is persisted" do
    held_while_fetching = nil
    stub_request(:get, OPEN_URL).to_return do
      held_while_fetching = !slot_free?(0)
      { status: 200, headers: { content_type: "application/json" }, body: { client_id: OPEN_URL, client_name: "Tools", redirect_uris: [ OPEN_CALLBACK ] }.to_json }
    end

    # Probed as the client's row is inserted, inside its creating transaction.
    free_while_persisting = nil
    persisting = ->(*, payload) do
      if free_while_persisting.nil? && payload[:sql].match?(/\AINSERT INTO [`"]?oauth_clients\b/i)
        free_while_persisting = :probing
        free_while_persisting = slot_free?(0)
      end
    end

    with_lease do
      ActiveSupport::Notifications.subscribed(persisting, "sql.active_record") do
        assert resolve_open(persist: true).client.persisted?
      end
    end

    assert held_while_fetching, "the fetch runs holding a slot"
    assert free_while_persisting, "the slot is released before the client is persisted"
  end

  test "an invalid identifier is an unknown client" do
    assert_equal :invalid_url, Oauth::ClientMetadata::Resolver.resolve_for_intake("https://claude.ai/x?y=1", requester: identities(:david)).outcome
  end

  test "a URL client_id never resolves a registered client" do
    Oauth::Client.create!(client_id: URL, name: "Imposter", redirect_uris: [ CALLBACK ])
    stub = stub_request(:get, URL)

    assert_equal :conflicting_client, resolve(persist: true).outcome
    assert_not_requested stub
  end

  # Identifiers are exact strings. MySQL's client_id collation folds case, so
  # there the variant's row can't be created and the variant is refused; SQLite
  # compares bytes, and gives it a row of its own. It never resolves to the
  # original's.
  test "a case variant of a provisioned client's URL never resolves to that client" do
    stub_document
    original = resolve(persist: true).client
    variant = "https://claude.ai/oauth/MCP-oauth-client-metadata"

    assert_nil Oauth::Client.find_presented(variant)

    stub_request(:get, variant).to_return(status: 200, body: document(client_id: variant).to_json, headers: { content_type: "application/json" })
    resolution = Oauth::ClientMetadata::Resolver.resolve_for_intake(variant, requester: identities(:david))

    if resolution.success?
      assert_equal variant, resolution.client.client_id
      assert_not_equal original, resolution.client
    else
      assert_equal :conflicting_client, resolution.outcome
    end
  end

  test "a failed fetch or an invalid document aborts, and stores nothing" do
    stub_request(:get, URL).to_return(status: 500)
    assert_equal :fetch_failed, resolve(persist: true).outcome

    stub_document(client_id: "https://claude.ai/someone-else")
    resolution = resolve(persist: true)
    assert_equal :invalid_document, resolution.outcome
    assert_match "client_id", resolution.error_description

    stub_document(redirect_uris: %w[ http://evil.example.com/callback ])
    assert_equal :invalid_document, resolve(persist: true).outcome

    assert_nil Oauth::Client.find_presented(URL)
  end

  test "losing a creation race adopts the winner" do
    stub_document
    resolver = Oauth::ClientMetadata::Resolver.new(URL, requester: identities(:david))
    winner = Oauth::Client.create!(client_id: URL, name: "Claude", redirect_uris: [ CALLBACK ], client_id_metadata_document: true)
    Oauth::Client.stubs(:find_presented).returns(nil).then.returns(winner)

    assert_equal winner, resolver.resolve(persist: true).client
  end

  test "fetches are limited per URL" do
    with_memory_cache do
      stub_request(:get, URL).to_return(status: 500)

      outcomes = Array.new(Oauth::ClientMetadata::Resolver::URL_ATTEMPT_LIMIT + 1) { resolve(persist: false).outcome }

      assert_equal [ :fetch_failed ] * Oauth::ClientMetadata::Resolver::URL_ATTEMPT_LIMIT + [ :throttled ], outcomes
    end
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "a fetch that loses admission to server pressure doesn't spend the budget" do
    with_memory_cache do
      Oauth::ClientMetadata::Fetcher.any_instance.stubs(:fetch).returns(Oauth::ClientMetadata::Fetcher::Result.failure(:overloaded))

      outcomes = Array.new(Oauth::ClientMetadata::Resolver::URL_ATTEMPT_LIMIT + 1) { resolve(persist: false).outcome }

      assert_equal [ :overloaded ] * (Oauth::ClientMetadata::Resolver::URL_ATTEMPT_LIMIT + 1), outcomes
    end
  end

  test "one person spending the fetch budget leaves everyone else's" do
    with_memory_cache do
      stub_request(:get, URL).to_return(status: 500)
      Oauth::ClientMetadata::Resolver::URL_ATTEMPT_LIMIT.times { resolve(persist: false) }
      assert_equal :throttled, resolve(persist: false).outcome

      stub_document
      assert resolve(persist: true, requester: identities(:kevin)).success?
    end
  end

  test "a provisioned client over the fetch budget keeps its stored document" do
    with_memory_cache do
      stub_document
      client = resolve(persist: true).client
      client.update!(metadata_expires_at: 1.minute.ago)

      stub_request(:get, URL).to_return(status: 500)
      Oauth::ClientMetadata::Resolver::URL_ATTEMPT_LIMIT.times { resolve(persist: true) }

      assert_equal client, resolve(persist: true).client
    end
  end

  private
    def resolve(persist:, requester: identities(:david))
      Oauth::ClientMetadata::Resolver.new(URL, requester: requester).resolve(persist: persist)
    end

    def document(**members)
      { client_id: URL, client_name: "Claude", redirect_uris: [ CALLBACK ], token_endpoint_auth_method: "none" }.merge(members)
    end

    def stub_document(etag: nil, **members)
      stub_request(:get, URL).to_return \
        status: 200, body: document(**members).to_json, headers: { content_type: "application/json", etag: etag }.compact
    end

    def resolve_open(persist:, requester: identities(:david))
      Oauth::ClientMetadata::Resolver.new(OPEN_URL, requester: requester).resolve(persist: persist)
    end

    # Grants to count open-tier apps, one each, on hosts apart from OPEN_URL's.
    def connect_open_tier_apps(identity, count, prefix: "app")
      Array.new(count) do |index|
        host = "#{prefix}#{index}.example.org"
        client = Oauth::Client.create!(client_id: "https://#{host}/client.json", name: "App #{index}", redirect_uris: [ "https://#{host}/callback" ], client_id_metadata_document: true)
        identity.access_tokens.create!(oauth_client: client)
      end
    end

    def with_raising_subscriber(*names, &block)
      raising = ->(*) { raise "subscriber failed" }
      names.reduce(block) { |inner, name| -> { ActiveSupport::Notifications.subscribed(raising, name, &inner) } }.call
    end

    def capture_refusals(&block)
      events = []
      ActiveSupport::Notifications.subscribed(->(event) { events << event.payload }, "cimd_refusal.oauth", &block)
      events
    end

    def stub_open_document(**members)
      stub_request(:get, OPEN_URL).to_return status: 200, headers: { content_type: "application/json" },
        body: { client_id: OPEN_URL, client_name: "Tools", redirect_uris: [ OPEN_CALLBACK ] }.merge(members).to_json
    end

    def with_memory_cache
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      Rails.cache = original
    end
end
