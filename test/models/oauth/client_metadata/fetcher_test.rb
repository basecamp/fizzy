require "test_helper"

class Oauth::ClientMetadata::FetcherTest < ActiveSupport::TestCase
  URL = "https://claude.ai/oauth/mcp-oauth-client-metadata"
  PUBLIC_IP = "160.79.104.10"

  setup do
    WebMock.disable_net_connect!
    stub_dns_resolution(PUBLIC_IP)
    @fetcher = Oauth::ClientMetadata::Fetcher.new
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "fetches a JSON document over the pinned address, with default freshness" do
    Oauth::ClientMetadata::Fetcher.connection_class.any_instance.expects(:ipaddr=).with(PUBLIC_IP)
    stub_request(:get, URL)
      .to_return(status: 200, body: %({"client_id":"#{URL}"}), headers: { content_type: "application/json" })

    result = @fetcher.fetch(URL)

    assert result.success?
    assert_equal %({"client_id":"#{URL}"}), result.body
    assert_nil result.etag
    assert_equal 1.hour, result.expires_in
  end

  test "refuses a host that resolves to a private, loopback or link-local address" do
    %w[ 10.0.0.5 127.0.0.1 169.254.169.254 ::1 fd00::1 ].each do |address|
      stub_dns_resolution(address)
      stub = stub_request(:get, URL)

      assert_equal :blocked_address, @fetcher.fetch(URL).outcome, address
      assert_not_requested stub
    end
  end

  test "refuses the special-purpose ranges the default policy admits" do
    { "64:ff9b::808:808" => "NAT64 of a public address", "192.52.193.1" => "AMT", "192.175.48.1" => "AS112" }.each do |address, range|
      stub_dns_resolution(address)
      stub = stub_request(:get, URL)

      assert_equal :blocked_address, @fetcher.fetch(URL).outcome, range
      assert_not_requested stub
    end
  end

  test "refuses a host whose answers mix public and blocked addresses" do
    stub_dns_resolution(PUBLIC_IP, "10.0.0.5")
    stub = stub_request(:get, URL)

    assert_equal :blocked_address, @fetcher.fetch(URL).outcome
    assert_not_requested stub
  end

  test "refuses a host that resolves to nothing" do
    stub_dns_failure

    assert_equal :unresolvable, @fetcher.fetch(URL).outcome
  end

  test "ignores a proxy in the environment" do
    stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "application/json" })

    with_env("https_proxy" => "http://proxy.internal:3128", "HTTPS_PROXY" => "http://proxy.internal:3128") do
      assert @fetcher.fetch(URL).success?
    end
  end

  test "accepts application/*+json and refuses other content types" do
    stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "application/oauth-client-metadata+json" })
    assert @fetcher.fetch(URL).success?

    stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "text/html" })
    assert_equal :wrong_content_type, @fetcher.fetch(URL).outcome
  end

  test "never follows a redirect" do
    stub_request(:get, URL).to_return(status: 302, headers: { location: "https://elsewhere.example.com/client.json" })

    assert_equal :redirect, @fetcher.fetch(URL).outcome
    assert_not_requested :get, "https://elsewhere.example.com/client.json"
  end

  test "refuses oversized documents, declared or not" do
    stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "application/json", content_length: 1.megabyte })
    assert_equal :too_large, @fetcher.fetch(URL).outcome

    stub_request(:get, URL).to_return(status: 200, body: "x" * 6.kilobytes, headers: { content_type: "application/json" })
    assert_equal :too_large, @fetcher.fetch(URL).outcome
  end

  test "asks for identity encoding and refuses any other" do
    stub_request(:get, URL).with(headers: { "Accept-Encoding" => "identity" })
      .to_return(status: 200, body: "{}", headers: { content_type: "application/json", content_encoding: "gzip" })

    assert_equal :wrong_content_encoding, @fetcher.fetch(URL).outcome
  end

  test "answers typed outcomes for HTTP errors, timeouts and connection failures" do
    stub_request(:get, URL).to_return(status: 404)
    assert_equal :http_error, @fetcher.fetch(URL).outcome

    stub_request(:get, URL).to_timeout
    assert_equal :timeout, @fetcher.fetch(URL).outcome

    stub_request(:get, URL).to_raise(Errno::ECONNREFUSED)
    assert_equal :connection_failed, @fetcher.fetch(URL).outcome

    stub_request(:get, URL).to_raise(OpenSSL::SSL::SSLError)
    assert_equal :tls_failed, @fetcher.fetch(URL).outcome
  end

  test "a saturated bulkhead answers overloaded without fetching" do
    stub = stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "application/json" })

    Oauth::ClientMetadata::Fetcher::Bulkhead.acquire do
      Oauth::ClientMetadata::Fetcher::Bulkhead.acquire do
        assert_equal :overloaded, @fetcher.fetch(URL).outcome
      end
    end

    assert_not_requested stub
    assert @fetcher.fetch(URL).success?
  end

  test "revalidates with a stored ETag" do
    stub_request(:get, URL).with(headers: { "If-None-Match" => %("v1") }).to_return(status: 304, headers: { etag: %("v2") })

    result = @fetcher.fetch(URL, etag: %("v1"))

    assert result.not_modified?
    assert_equal %("v2"), result.etag
  end

  test "a 304 to a request that sent no ETag validates nothing" do
    stub_request(:get, URL).to_return(status: 304)

    assert_equal :unexpected_not_modified, @fetcher.fetch(URL).outcome
  end

  test "freshness follows the document's caching headers, within bounds" do
    { "max-age=600" => 10.minutes, "max-age=10" => 5.minutes, "max-age=999999" => 24.hours, "no-store" => 5.minutes }.each do |cache_control, expected|
      stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "application/json", cache_control: cache_control })

      assert_equal expected, @fetcher.fetch(URL).expires_in, cache_control
    end
  end

  test "drops an ETag that doesn't fit the column" do
    stub_request(:get, URL).to_return(status: 200, body: "{}", headers: { content_type: "application/json", etag: %("#{"x" * 200}") })

    assert_nil @fetcher.fetch(URL).etag
  end

  private
    def with_env(variables)
      saved = variables.keys.to_h { |key| [ key, ENV[key] ] }
      variables.each { |key, value| ENV[key] = value }
      yield
    ensure
      saved.each { |key, value| ENV[key] = value }
    end
end
