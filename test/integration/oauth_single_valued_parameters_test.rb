require "test_helper"

# RFC 6749 §3.1: request parameters MUST NOT be included more than once. Rails
# parses a name[]= form field or a JSON array or object into an Array or a
# nested Parameters, so each endpoint refuses that shape before any lookup.
class OauthSingleValuedParametersTest < ActionDispatch::IntegrationTest
  CHALLENGE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

  setup do
    @client = oauth_clients(:mcp_client)
  end

  # Authorization endpoint

  test "an array client_id is refused before it becomes an IN list" do
    sign_in_as :david

    assert_no_queries_match(/oauth_clients/) do
      untenanted { get new_oauth_authorization_path, params: authorize_params(client_id: [ @client.client_id ]) }
    end

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
    assert_match "client_id", response.body
  end

  test "an array redirect_uri is shown an error, never redirected to" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: authorize_params(redirect_uri: [ "http://127.0.0.1:8888/callback" ]) }

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
    assert_nil response.location
  end

  test "an array or object in any other authorization parameter goes back to a vetted client as invalid_request" do
    sign_in_as :david

    { scope: [ "read" ], response_type: [ "code" ], code_challenge: [ CHALLENGE ], code_challenge_method: [ "S256" ], state: { a: "b" } }.each do |name, value|
      untenanted { get new_oauth_authorization_path, params: authorize_params(name => value) }

      assert_response :redirect, name.to_s
      query = URI.decode_www_form(URI.parse(response.location).query).to_h
      assert_equal "invalid_request", query["error"], name.to_s
      assert_match name.to_s, query["error_description"]
      assert_not query.key?("code")
    end
  end

  test "an array in another authorization parameter from an unvetted client is shown here" do
    sign_in_as :david
    @client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], dynamically_registered: true)

    untenanted { get new_oauth_authorization_path, params: authorize_params(redirect_uri: "https://connector.example.com/callback", scope: [ "read" ]) }

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
  end

  test "the consent POST refuses an array client_id" do
    sign_in_as :david

    assert_no_queries_match(/oauth_clients/) do
      untenanted { post oauth_authorization_path, params: authorize_params(client_id: [ @client.client_id ]) }
    end

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
  end

  test "a dark server still answers 404 to a malformed request" do
    with_oauth_acceptance(false) do
      untenanted { get new_oauth_authorization_path, params: authorize_params(client_id: [ @client.client_id ]) }
    end

    assert_response :not_found
  end

  # Token endpoint

  test "the token endpoint refuses an array client_id before any lookup" do
    assert_no_queries_match(/oauth_clients|identity_access_tokens/) do
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: "fizzy_rt_x", client_id: [ @client.client_id ] }, as: :json
      end
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "the token endpoint refuses an array or object in any single-valued parameter" do
    [
      { grant_type: [ "refresh_token" ], refresh_token: "fizzy_rt_x", client_id: @client.client_id },
      { grant_type: "refresh_token", refresh_token: [ "fizzy_rt_x" ], client_id: @client.client_id },
      { grant_type: "refresh_token", refresh_token: "fizzy_rt_x", client_id: @client.client_id, scope: [ "read" ] },
      { grant_type: "authorization_code", code: { a: "b" }, code_verifier: "v", redirect_uri: "http://127.0.0.1:8888/callback", client_id: @client.client_id }
    ].each do |body|
      untenanted { post oauth_token_path, params: body, as: :json }

      assert_response :bad_request, body.inspect
      assert_equal "invalid_request", response.parsed_body["error"], body.inspect
    end
  end

  test "a refresh's JSON null scope still means no scope, not a malformed one" do
    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: "fizzy_rt_unknown", client_id: @client.client_id, scope: nil }, as: :json
    end

    assert_equal "invalid_grant", response.parsed_body["error"], response.body
  end

  # Revocation endpoint

  test "revocation refuses an array client_id or token_type_hint before any lookup" do
    [ { token: "x", client_id: [ @client.client_id ] }, { token: "x", token_type_hint: [ "access_token" ] } ].each do |body|
      assert_no_queries_match(/oauth_clients|identity_access_tokens/) do
        untenanted { post oauth_revocation_path, params: body, as: :json }
      end

      assert_response :bad_request, body.inspect
      assert_equal "invalid_request", response.parsed_body["error"], body.inspect
    end
  end

  # Dynamic client registration

  test "registration refuses an array in a single-valued parameter, and still takes scope as a list" do
    untenanted do
      post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/cb" ], client_id: [ "chosen" ] }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", response.parsed_body["error"]

    untenanted do
      post oauth_clients_path, params: { redirect_uris: [ "http://127.0.0.1:9999/cb" ], scope: [ "read" ] }, as: :json
    end

    assert_response :created
    assert_equal "read", response.parsed_body["scope"]
  end

  private
    def authorize_params(**overrides)
      {
        client_id: @client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: CHALLENGE,
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz"
      }.merge(overrides)
    end

    def with_oauth_acceptance(enabled)
      previous = Rails.configuration.x.oauth.acceptance_enabled
      Rails.configuration.x.oauth.acceptance_enabled = enabled
      yield
    ensure
      Rails.configuration.x.oauth.acceptance_enabled = previous
    end
end
