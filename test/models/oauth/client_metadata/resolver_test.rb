require "test_helper"

class Oauth::ClientMetadata::ResolverTest < ActiveSupport::TestCase
  include OauthAuditTestHelper

  URL = "https://claude.ai/oauth/mcp-oauth-client-metadata"
  CALLBACK = "https://claude.ai/api/mcp/auth_callback"

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

  test "never fetches from a host that isn't allowlisted" do
    url = "https://tools.example.com/client.json"
    stub = stub_request(:get, url)

    resolution = Oauth::ClientMetadata::Resolver.resolve_for_intake(url, requester: identities(:david))

    assert_equal :unrecognized_host, resolution.outcome
    assert_equal "Unknown client", resolution.error_description
    assert_not_requested stub
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

    def with_memory_cache
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      Rails.cache = original
    end
end
