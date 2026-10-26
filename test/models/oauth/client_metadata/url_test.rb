require "test_helper"

class Oauth::ClientMetadata::UrlTest < ActiveSupport::TestCase
  test "an https URL with a path is a valid identifier" do
    assert Oauth::ClientMetadata::Url.valid?("https://claude.ai/oauth/mcp-oauth-client-metadata")
    assert_equal "claude.ai", Oauth::ClientMetadata::Url.host("https://claude.ai/oauth/mcp-oauth-client-metadata")
  end

  test "refuses anything that would need normalizing" do
    [
      "http://claude.ai/client.json",
      "HTTPS://claude.ai/client.json",
      "https://claude.ai",
      "https://claude.ai/a/../client.json",
      "https://claude.ai/./client.json",
      "https://claude.ai/client.json#frag",
      "https://claude.ai/client.json?v=1",
      "https://user@claude.ai/client.json",
      "https://claude.ai/#{"a" * 255}",
      "not a url",
      nil,
      [ "https://claude.ai/client.json" ]
    ].each do |client_id|
      assert_not Oauth::ClientMetadata::Url.valid?(client_id), client_id.inspect
    end
  end

  test "anything URL-shaped takes the metadata document path, valid or not" do
    assert Oauth::ClientMetadata::Url.url_shaped?("https://claude.ai/client.json")
    assert Oauth::ClientMetadata::Url.url_shaped?("HTTP://claude.ai/x?y")
    assert_not Oauth::ClientMetadata::Url.url_shaped?("mcp_test_client_123")
    assert_not Oauth::ClientMetadata::Url.url_shaped?([ "https://claude.ai/client.json" ])
  end

  test "recognizes only the exact allowlisted hosts" do
    assert Oauth::ClientMetadata.recognized?("https://claude.ai/client.json")
    assert Oauth::ClientMetadata.recognized?("https://chatgpt.com/client.json")
    assert_not Oauth::ClientMetadata.recognized?("https://evil.claude.ai/client.json")
    assert_not Oauth::ClientMetadata.recognized?("https://claude.ai.example.com/client.json")
    assert_not Oauth::ClientMetadata.recognized?("https://CLAUDE.AI/client.json")
    assert_not Oauth::ClientMetadata.recognized?("https://tools.example.com/client.json")
  end
end
