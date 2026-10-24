require "test_helper"

class Oauth::ClientMetadata::DocumentTest < ActiveSupport::TestCase
  URL = "https://claude.ai/oauth/mcp-oauth-client-metadata"

  test "maps a valid document to client attributes" do
    document = parse(client_name: "Claude", scope: "read write")

    assert document.valid?
    assert_equal({ name: "Claude", redirect_uris: %w[ https://claude.ai/api/mcp/auth_callback ], scopes: %w[ read write ] }, document.attributes)
  end

  test "the client_id member must be exactly the document URL" do
    assert_not parse(client_id: URL.upcase).valid?
    assert_not parse(client_id: "#{URL}/").valid?
    assert_not parse(client_id: nil).valid?
  end

  test "refuses documents carrying secrets" do
    document = parse(client_secret: "s3cret")

    assert_not document.valid?
    assert_match "client_secret", document.error_description
  end

  test "is provisioned public whenever the client offers none" do
    assert parse(token_endpoint_auth_method: "private_key_jwt", token_endpoint_auth_methods_supported: %w[ private_key_jwt none ]).valid?
    assert_not parse(token_endpoint_auth_method: "private_key_jwt").valid?
    assert_not parse(token_endpoint_auth_methods_supported: %w[ client_secret_basic ]).valid?
    assert_not parse(token_endpoint_auth_method: "none", token_endpoint_auth_methods_supported: %w[ private_key_jwt ]).valid?
  end

  test "grant types must include the authorization code grant, and extra ones are ignored" do
    assert parse(grant_types: %w[ authorization_code refresh_token urn:ietf:params:oauth:grant-type:token-exchange ]).valid?
    assert_not parse(grant_types: %w[ client_credentials ]).valid?
    assert_not parse(grant_types: "authorization_code").valid?
  end

  test "redirect_uris are required and bounded" do
    assert_not parse(redirect_uris: nil).valid?
    assert_not parse(redirect_uris: []).valid?
    assert_not parse(redirect_uris: [ 1 ]).valid?
    assert_not parse(redirect_uris: Array.new(Oauth::Client::MAXIMUM_REDIRECT_URIS + 1) { |i| "https://claude.ai/#{i}" }).valid?
  end

  test "scopes narrow to Fizzy's, and write brings read" do
    assert_equal %w[ read write ], parse(scope: "write offline_access").attributes[:scopes]
    assert_equal %w[ read ], parse(scope: "read mcp").attributes[:scopes]
    assert_equal %w[ read write ], parse.attributes[:scopes], "silence offers both"
    assert_not parse(scope: "offline_access").valid?
    assert_not parse(scope: [ "read" ]).valid?
  end

  test "names the client by its host when it names none" do
    assert_equal "claude.ai", parse(client_name: " ").attributes[:name]
    assert_equal 255, parse(client_name: "x" * 300).attributes[:name].length
  end

  test "refuses what isn't a UTF-8 JSON object" do
    assert_not Oauth::ClientMetadata::Document.parse("[]", client_id: URL).valid?
    assert_not Oauth::ClientMetadata::Document.parse("{", client_id: URL).valid?
    assert_not Oauth::ClientMetadata::Document.parse(%({"client_id":"\xFF"}).b, client_id: URL).valid?
  end

  private
    def parse(**members)
      body = { client_id: URL, redirect_uris: %w[ https://claude.ai/api/mcp/auth_callback ] }.merge(members).compact
      Oauth::ClientMetadata::Document.parse(body.to_json, client_id: URL)
    end
end
