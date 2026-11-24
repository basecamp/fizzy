require "test_helper"

class OauthClientMetadataDocumentsTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  URL = "https://claude.ai/oauth/mcp-oauth-client-metadata"
  CALLBACK = "https://claude.ai/api/mcp/auth_callback"
  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  OPEN_URL = "https://tools.example.com/client.json"
  OPEN_CALLBACK = "https://tools.example.com/callback"

  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_dns_resolution("160.79.104.10")
    stub_request(:get, URL).to_return \
      status: 200,
      body: { client_id: URL, client_name: "Claude", redirect_uris: [ CALLBACK ], scope: "read write" }.to_json,
      headers: { content_type: "application/json" }
    stub_request(:get, OPEN_URL).to_return \
      status: 200,
      body: { client_id: OPEN_URL, client_name: "Tools", redirect_uris: [ OPEN_CALLBACK ], scope: "read write" }.to_json,
      headers: { content_type: "application/json" }
  end

  test "metadata advertises metadata documents only while they're on" do
    untenanted { get "/.well-known/oauth-authorization-server" }
    assert_equal true, response.parsed_body["client_id_metadata_document_supported"]

    with_metadata_documents(false) do
      untenanted { get "/.well-known/oauth-authorization-server" }
      assert_not response.parsed_body.key?("client_id_metadata_document_supported")
    end
  end

  test "the consent screen renders from the document without registering the client" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: authorization }

    assert_response :success
    assert_select "h1", text: "Connect this app to Fizzy?"
    assert_select ".oauth-client__name bdi", text: "Claude"
    assert_select ".oauth-client__byline", text: "Name set by the app at claude.ai"
    assert_select ".oauth-client__warning", count: 0
    assert_nil Oauth::Client.find_presented(URL)
  end

  test "consenting provisions the client, and its code redeems for tokens" do
    sign_in_as :david

    untenanted { post oauth_authorization_path, params: authorization }

    assert_response :redirect
    assert response.location.start_with?("#{CALLBACK}?")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    assert Oauth::Client.find_presented(URL).metadata_document?

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code", client_id: URL, code: code, redirect_uri: CALLBACK, code_verifier: CODE_VERIFIER
      }, as: :json
    end

    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
    assert_predicate response.parsed_body["refresh_token"], :present?
  end

  test "Perplexity connects with its published document and callback" do
    url = "https://www.perplexity.ai/.well-known/mcp-client.json"
    callback = "https://www.perplexity.ai/rest/connections/oauth_callback"
    stub_request(:get, url).to_return \
      status: 200, body: file_fixture("oauth/perplexity_client_metadata.json").read, headers: { content_type: "application/json" }
    params = authorization.merge(client_id: url, redirect_uri: callback)
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: params }

    assert_response :success
    assert_select ".oauth-client__name bdi", text: "Perplexity"
    assert_select ".oauth-client__byline", text: "Name set by the app at www.perplexity.ai"

    untenanted { post oauth_authorization_path, params: params }

    assert_response :redirect
    assert response.location.start_with?("#{callback}?")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    assert Oauth::Client.find_presented(url).metadata_document?

    untenanted do
      post oauth_token_path, params: {
        grant_type: "authorization_code", client_id: url, code: code, redirect_uri: callback, code_verifier: CODE_VERIFIER
      }, as: :json
    end

    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
  end

  test "switching who is signed in registers nothing" do
    sign_in_as :david

    untenanted { post oauth_authorization_switch_path, params: authorization }

    assert_response :redirect
    assert_nil Oauth::Client.find_presented(URL)
  end

  test "Connected apps names the host that set a metadata document client's name" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: authorization }
    identities(:david).access_tokens.create! oauth_client: Oauth::Client.find_presented(URL), permission: :read

    untenanted { get my_connected_apps_path }

    assert_select ".connected-app", text: /Name set by the app at claude\.ai/
  end

  test "denying registers nothing" do
    sign_in_as :david

    untenanted { post oauth_authorization_path, params: authorization.merge(error: "access_denied") }

    assert_response :redirect
    assert_equal "access_denied", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
    assert_nil Oauth::Client.find_presented(URL)
  end

  test "denying against a stale row that allows less than the document still answers access_denied" do
    Oauth::Client.create! client_id: URL, name: "Claude", redirect_uris: [ CALLBACK ], scopes: %w[ read ], client_id_metadata_document: true,
      metadata_fetched_at: 2.days.ago, metadata_expires_at: 1.day.ago
    sign_in_as :david

    untenanted { post oauth_authorization_path, params: authorization.merge(scope: "read write", error: "access_denied") }

    assert_response :redirect
    assert_equal "access_denied", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
  end

  test "while open registration is off, a host that isn't allowlisted is an unknown client, and never fetched" do
    sign_in_as :david
    stub = stub_request(:get, OPEN_URL)

    with_oauth_config(cimd_open_registration: false) do
      untenanted { get new_oauth_authorization_path, params: open_authorization }
    end

    assert_response :bad_request
    assert_select "p", text: Oauth::AuthorizationsController::UNKNOWN_CLIENT_MESSAGE
    assert_not_requested stub
  end

  test "while open registration is off, a client provisioned from a host that isn't allowlisted is unknown" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: open_authorization }
    assert Oauth::Client.find_presented(OPEN_URL)

    with_oauth_config(cimd_open_registration: false) do
      untenanted { get new_oauth_authorization_path, params: open_authorization }
      assert_response :bad_request
      assert_select "p", text: Oauth::AuthorizationsController::UNKNOWN_CLIENT_MESSAGE

      untenanted { post oauth_authorization_path, params: open_authorization }
      assert_response :bad_request
    end
  end

  test "the consent screen warns that we don't know an app from a host that isn't allowlisted" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: open_authorization }

    assert_response :success
    assert_select ".oauth-client__name bdi", text: "Tools"
    assert_select ".oauth-client__warning", text: /We don.t know this app\. Only authorize it if you trust tools\.example\.com\./
    assert_nil Oauth::Client.find_presented(OPEN_URL)
  end

  test "a lookalike of an allowlisted host is warned about" do
    url = "https://claude.ai.example.com/client.json"
    stub_request(:get, url).to_return status: 200, headers: { content_type: "application/json" },
      body: { client_id: url, client_name: "Claude", redirect_uris: [ "https://claude.ai.example.com/callback" ] }.to_json
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: authorization.merge(client_id: url, redirect_uri: "https://claude.ai.example.com/callback") }

    assert_response :success
    assert_select ".oauth-client__warning", text: /trust claude\.ai\.example\.com/
  end

  test "consenting to an app from a host that isn't allowlisted provisions it, and Connected apps says we don't know it" do
    sign_in_as :david

    untenanted { post oauth_authorization_path, params: open_authorization }

    assert_response :redirect
    assert response.location.start_with?("#{OPEN_CALLBACK}?")
    client = Oauth::Client.find_presented(OPEN_URL)
    assert client.metadata_document?

    untenanted { get new_oauth_authorization_path, params: open_authorization }
    assert_select ".oauth-client__warning", text: /trust tools\.example\.com/

    identities(:david).access_tokens.create! oauth_client: client, permission: :read
    untenanted { get my_connected_apps_path }
    assert_select ".connected-app", text: /Name set by the app at tools\.example\.com/
    assert_select ".connected-app__unrecognized", text: /Unrecognized developer/
  end

  test "with the fetch lease on, consent reads and the authorization registers, holding no slot after" do
    Dir.mktmpdir do |directory|
      Oauth::ClientMetadata::FetchLease.stubs(:slots_directory).returns(directory)
      sign_in_as :david

      events = []
      ActiveSupport::Notifications.subscribed(->(event) { events << [ event.name, event.payload ] }, /\Acimd_lease/) do
        with_oauth_config(cimd_fetch_lease: true) do
          untenanted { get new_oauth_authorization_path, params: open_authorization }
          assert_response :success

          untenanted { post oauth_authorization_path, params: open_authorization }
          assert_response :redirect
        end
      end

      assert Oauth::Client.find_presented(OPEN_URL)
      assert_equal [ [ "cimd_lease.oauth", { outcome: :admitted } ] ] * 2, events
      Oauth::ClientMetadata::FetchLease::SLOTS.times do |index|
        assert lease_slot_free?(index, directory), "slot #{index} is released"
      end
    end
  ensure
    Oauth::Client.with_connection { |connection| connection.query_value("SELECT RELEASE_ALL_LOCKS()") if connection.adapter_name.match?(/mysql/i) }
  end

  test "Connected apps says nothing of the kind for an allowlisted host" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: authorization }
    identities(:david).access_tokens.create! oauth_client: Oauth::Client.find_presented(URL), permission: :read

    untenanted { get my_connected_apps_path }

    assert_select ".connected-app", text: /Name set by the app at claude\.ai/
    assert_select ".connected-app__unrecognized", count: 0
  end

  test "a document that can't be fetched refuses the authorization" do
    sign_in_as :david
    stub_request(:get, URL).to_return(status: 404)

    untenanted { get new_oauth_authorization_path, params: authorization }

    assert_response :bad_request
    assert_select "h2", text: "Can't authorize this app"
    assert_select "[data-oauth-error=?]", "invalid_client_metadata"

    untenanted { get new_oauth_authorization_path(format: :json), params: authorization }

    assert_response :bad_request
    assert_equal "invalid_client_metadata", response.parsed_body["error"]
  end

  test "while off, a URL client_id is an unknown client, provisioned or not" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: authorization }
    assert Oauth::Client.find_presented(URL)

    with_metadata_documents(false) do
      untenanted { get new_oauth_authorization_path, params: authorization }
    end

    assert_response :bad_request
    assert_select "p", text: Oauth::AuthorizationsController::UNKNOWN_CLIENT_MESSAGE
  end

  test "a client_id array never reaches a metadata document client" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: authorization }
    assert Oauth::Client.find_presented(URL)

    # Refused by the single-valued check before any client lookup, so it
    # neither becomes an IN list nor gets past the switch.
    [ false, true ].each do |enabled|
      with_metadata_documents(enabled) do
        assert_no_queries_match(/oauth_clients/) do
          untenanted { post oauth_authorization_path, params: authorization.merge(client_id: [ URL ]) }
        end
      end

      assert_response :bad_request
      assert_select "[data-oauth-error=?]", "invalid_request"
      assert_select "p", text: OauthHelper::OAUTH_ERROR_MESSAGES["invalid_request"]
    end
  end

  test "a metadata document client isn't reachable by a client_id that isn't its URL" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: authorization }
    client = Oauth::Client.find_presented(URL)
    client.update_columns(client_id: "not-a-url-#{client.id}")

    untenanted { get new_oauth_authorization_path, params: authorization.merge(client_id: client.client_id) }

    assert_response :bad_request
    assert_select "p", text: Oauth::AuthorizationsController::UNKNOWN_CLIENT_MESSAGE
  end

  test "an unvetted redirect gets no error redirect before consent" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: authorization.merge(code_challenge_method: "plain") }

    assert_response :bad_request
    assert_select "[data-oauth-error=?]", "invalid_request"
  end

  teardown do
    WebMock.allow_net_connect!
  end

  private
    def authorization
      {
        client_id: URL,
        redirect_uri: CALLBACK,
        response_type: "code",
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false),
        code_challenge_method: "S256",
        scope: "read write",
        state: "xyz"
      }
    end

    def lease_slot_free?(index, directory)
      Oauth::Client.with_connection do |connection|
        if connection.adapter_name.match?(/mysql/i)
          connection.query_value("SELECT IS_FREE_LOCK(#{connection.quote(Oauth::ClientMetadata::FetchLease::NamedLocks.lock_name(connection, index))})") == 1
        else
          File.open(File.join(directory, "slot-#{index}.lock"), File::RDWR | File::CREAT) do |file|
            file.flock(File::LOCK_EX | File::LOCK_NB).tap { file.flock(File::LOCK_UN) }
          end
        end
      end
    end

    def open_authorization
      authorization.merge(client_id: OPEN_URL, redirect_uri: OPEN_CALLBACK)
    end

    def with_metadata_documents(enabled)
      config = Rails.application.config.x.oauth
      saved = config.cimd_enabled
      config.cimd_enabled = enabled
      yield
    ensure
      config.cimd_enabled = saved
    end
end
