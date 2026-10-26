require "test_helper"

class My::ConnectedAppsControllerTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

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

  test "an app whose grants are bound to accounts is shown reaching only those" do
    resource = "https://mcp.example.com/mcp"
    saved, Rails.application.config.x.oauth.mcp_resources = Rails.application.config.x.oauth.mcp_resources, [ resource ]
    @identity.access_tokens.create! oauth_client: oauth_clients(:mcp_client), permission: :read, audience: resource, account: accounts("37s")

    get my_connected_apps_path

    assert_select ".connected-app__access", text: /in #{accounts("37s").name}\z/
    assert_no_match "in every account you belong to", response.body
  ensure
    Rails.application.config.x.oauth.mcp_resources = saved
  end

  test "an app's reach pairs each permission with the accounts it holds it in" do
    resource = "https://mcp.example.com/mcp"
    saved, Rails.application.config.x.oauth.mcp_resources = Rails.application.config.x.oauth.mcp_resources, [ resource ]
    @identity.access_tokens.create! oauth_client: oauth_clients(:mcp_client), permission: :write, audience: resource, account: accounts("37s")
    @identity.access_tokens.create! oauth_client: oauth_clients(:mcp_client), permission: :read, audience: resource, account: accounts(:initech)

    get my_connected_apps_path

    assert_select ".connected-app__access", count: 2
    assert_select ".connected-app__access", text: /Read and write.*in #{accounts("37s").name}\z/m
    assert_select ".connected-app__access", text: /\ARead only.*in #{accounts(:initech).name}\z/m
  ensure
    Rails.application.config.x.oauth.mcp_resources = saved
  end

  test "a grant bound to a deleted account reaches nothing, and the page still renders" do
    resource = "https://mcp.example.com/mcp"
    saved, Rails.application.config.x.oauth.mcp_resources = Rails.application.config.x.oauth.mcp_resources, [ resource ]
    grant = @identity.access_tokens.create! oauth_client: oauth_clients(:mcp_client), permission: :read, audience: resource, account: accounts("37s")
    grant.update_columns account_id: ActiveRecord::FixtureSet.identify("deleted", :uuid)

    get my_connected_apps_path

    assert_response :success
    assert_select ".connected-app__access", count: 0
  ensure
    Rails.application.config.x.oauth.mcp_resources = saved
  end

  test "index and destroy work untenanted, so an identity without an account can still disconnect apps" do
    client = oauth_clients(:mcp_client)
    @identity.access_tokens.create!(oauth_client: client, permission: :read)

    untenanted do
      get my_connected_apps_path

      assert_response :success
      assert_match client.name, response.body
      assert_in_body session_menu_path

      assert_difference -> { @identity.access_tokens.oauth.count }, -1 do
        delete my_connected_app_path(client)
      end
    end
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

  test "index groups apps by kind and says what each can do" do
    @identity.access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :read)
    @identity.access_tokens.create!(oauth_client: oauth_clients(:confidential_client), permission: :write)

    get my_connected_apps_path

    assert_response :success
    assert_select ".connected-apps__group", count: 2
    assert_select "#connected_apps_web + .connected-app, #connected_apps_web ~ .connected-app", text: /Confidential Connector.*Read and write/m
    assert_select "#connected_apps_local ~ .connected-app", text: /Test MCP Client.*Name set by an app on your device.*Read only/m
    assert_select "#connected_apps_fizzy", count: 0
    assert_select ".connected-app", text: /access last renewed/
  end

  test "index names where a self-registered web app's access goes" do
    @identity.access_tokens.create!(oauth_client: oauth_clients(:confidential_client), permission: :read)

    get my_connected_apps_path

    assert_select ".connected-app", text: /Name set by the app at connector.example.com/
  end

  test "index shows an empty state when nothing is connected" do
    get my_connected_apps_path

    assert_response :success
    assert_select ".connected-apps__empty", text: /Nothing connected yet/
    assert_select ".connected-app", count: 0
  end

  test "index names every remote host a self-registered app can send its access to, not just the first" do
    client = with_dcr_allowed_https_hosts "one.example.com", "two.example.com" do
      Oauth::Client.create! name: "Two Homes", dynamically_registered: true,
        redirect_uris: %w[ http://127.0.0.1:8888/callback https://one.example.com/cb https://two.example.com:8443/cb ]
    end
    @identity.access_tokens.create!(oauth_client: client, permission: :read)

    get my_connected_apps_path

    assert_select "#connected_apps_web ~ .connected-app", text: /Name set by the app at one.example.com or two.example.com:8443/
    assert_no_match "Name set by an app on your device", response.body
  end
end
