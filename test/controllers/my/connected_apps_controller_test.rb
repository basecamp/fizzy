require "test_helper"

class My::ConnectedAppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @identity = identities(:david)
  end

  test "index shows connected OAuth apps" do
    client = oauth_clients(:mcp_client)
    @identity.access_tokens.create!(oauth_client: client, permission: :read)

    get my_connected_apps_path
    assert_response :success
    assert_match client.name, response.body
  end

  test "index excludes PATs" do
    # PAT has no oauth_client
    @identity.access_tokens.create!(permission: :read, description: "My PAT")

    get my_connected_apps_path
    assert_response :success
    assert_no_match "My PAT", response.body
  end

  test "destroy revokes all tokens for a client" do
    client = oauth_clients(:mcp_client)
    @identity.access_tokens.create!(oauth_client: client, permission: :read)
    @identity.access_tokens.create!(oauth_client: client, permission: :write)

    assert_difference "Identity::AccessToken.count", -2 do
      delete my_connected_app_path(client)
    end

    assert_redirected_to my_connected_apps_path
    assert_match "disconnected", flash[:notice]
  end

  test "destroy only revokes tokens for the specified client" do
    client1 = oauth_clients(:mcp_client)
    client2 = Oauth::Client.create!(name: "Other App", redirect_uris: %w[ http://127.0.0.1/cb ])

    @identity.access_tokens.create!(oauth_client: client1, permission: :read)
    @identity.access_tokens.create!(oauth_client: client2, permission: :read)

    assert_difference "Identity::AccessToken.count", -1 do
      delete my_connected_app_path(client1)
    end

    assert @identity.access_tokens.exists?(oauth_client: client2)
  end

  test "destroy returns 404 for unconnected client" do
    client = oauth_clients(:mcp_client)
    # No tokens for this client

    delete my_connected_app_path(client)
    assert_response :not_found
  end
end
