require "test_helper"

class OauthClientMetadataDocumentsTest < ActionDispatch::IntegrationTest
  URL = "https://claude.ai/oauth/mcp-oauth-client-metadata"
  CALLBACK = "https://claude.ai/api/mcp/auth_callback"
  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_dns_resolution("160.79.104.10")
    stub_request(:get, URL).to_return \
      status: 200,
      body: { client_id: URL, client_name: "Claude", redirect_uris: [ CALLBACK ], scope: "read write" }.to_json,
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
    assert_match "Claude", response.body
    assert_match "Name set by the app at", response.body
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

  test "a host that isn't allowlisted is an unknown client, and never fetched" do
    sign_in_as :david
    url = "https://tools.example.com/client.json"
    stub = stub_request(:get, url)

    untenanted { get new_oauth_authorization_path, params: authorization.merge(client_id: url, redirect_uri: "https://tools.example.com/cb") }

    assert_response :bad_request
    assert_select "p", text: "Unknown client"
    assert_not_requested stub
  end

  test "a document that can't be fetched refuses the authorization" do
    sign_in_as :david
    stub_request(:get, URL).to_return(status: 404)

    untenanted { get new_oauth_authorization_path, params: authorization }

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
    assert_select "p", text: "Unknown client"
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
      assert_select "code", text: "invalid_request"
      assert_match "client_id", response.body
    end
  end

  test "a metadata document client isn't reachable by a client_id that isn't its URL" do
    sign_in_as :david
    untenanted { post oauth_authorization_path, params: authorization }
    client = Oauth::Client.find_presented(URL)
    client.update_columns(client_id: "not-a-url-#{client.id}")

    untenanted { get new_oauth_authorization_path, params: authorization.merge(client_id: client.client_id) }

    assert_response :bad_request
    assert_select "p", text: "Unknown client"
  end

  test "an unvetted redirect gets no error redirect before consent" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: authorization.merge(code_challenge_method: "plain") }

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
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

    def with_metadata_documents(enabled)
      config = Rails.application.config.x.oauth
      saved = config.cimd_enabled
      config.cimd_enabled = enabled
      yield
    ensure
      config.cimd_enabled = saved
    end
end
