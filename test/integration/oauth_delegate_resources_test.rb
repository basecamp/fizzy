require "test_helper"

# An OAuth grant is a delegate: the user handed an app authority to act for
# them. What it sets up falls into two kinds. Plumbing that delivers to the
# app itself, like a push subscription for the app's own device, belongs to
# the app and ends when the identity's last grant to it ends. Resources the
# delegate set up for the account, like a webhook, belong to the account:
# they outlive the grant, attributed to the person and the app, and the
# person may choose to remove them when they disconnect the app.
class OauthDelegateResourcesTest < ActionDispatch::IntegrationTest
  ENDPOINT = "https://fcm.googleapis.com/fcm/send/app-device"
  BROWSER = "https://fcm.googleapis.com/fcm/send/browser"

  setup do
    stub_web_push_dns_resolution

    @client = oauth_clients(:mcp_client)
    @grant = identities(:kevin).access_tokens.create!(oauth_client: @client, permission: :write)
  end

  test "a push subscription created through a grant belongs to its client" do
    subscribe_push bearer(@grant)

    assert_response :created
    assert_equal @client, app_subscription.oauth_client
  end

  test "disconnecting the app removes its push subscriptions" do
    subscribe_push bearer(@grant)

    sign_in_as :kevin
    delete my_connected_app_path(@client)

    assert_redirected_to my_connected_apps_path
    assert_not Push::Subscription.exists?(endpoint: ENDPOINT)
  end

  test "revoking the grant removes the app's push subscriptions" do
    subscribe_push bearer(@grant)

    untenanted { post oauth_revocation_path, params: { token: @grant.token, client_id: @client.client_id } }

    assert_response :success
    assert_not Identity::AccessToken.exists?(@grant.id)
    assert_not Push::Subscription.exists?(endpoint: ENDPOINT)
  end

  test "a grant lapsing idle removes the app's push subscriptions" do
    subscribe_push bearer(@grant)

    travel Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.second
    Identity::AccessToken.cleanup

    assert_not Identity::AccessToken.exists?(@grant.id)
    assert_not Push::Subscription.exists?(endpoint: ENDPOINT)
  end

  test "a replayed refresh token revoking the grant removes the app's push subscriptions" do
    subscribe_push bearer(@grant)
    presented = @grant.refresh_token
    refresh presented
    assert_response :success

    travel 1.day
    refresh presented

    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_not Identity::AccessToken.exists?(@grant.id)
    assert_not Push::Subscription.exists?(endpoint: ENDPOINT)
  end

  test "the app's push subscriptions last until its last grant to the identity ends" do
    other_grant = identities(:kevin).access_tokens.create!(oauth_client: @client, permission: :read)
    subscribe_push bearer(@grant)

    @grant.destroy
    assert Push::Subscription.exists?(endpoint: ENDPOINT)

    other_grant.destroy
    assert_not Push::Subscription.exists?(endpoint: ENDPOINT)
  end

  test "registering an endpoint again hands it to whoever registered it last" do
    subscribe_push bearer(@grant)

    reregistered = Oauth::Client.create!(name: "Test MCP Client", redirect_uris: %w[ http://127.0.0.1:8888/callback ], dynamically_registered: true)
    subscribe_push bearer(identities(:kevin).access_tokens.create!(oauth_client: reregistered, permission: :write))
    assert_equal reregistered, app_subscription.oauth_client

    @grant.destroy
    assert Push::Subscription.exists?(endpoint: ENDPOINT)

    sign_in_as :kevin
    post user_push_subscriptions_path(users(:kevin)), params: { push_subscription: push_params(ENDPOINT) }
    assert_nil app_subscription.oauth_client
  end

  # Delivery is where the leak would be, so the guarantee lives there: an app's
  # subscription delivers only while the user's identity holds a live grant to
  # that app. Cleanup on grant destroy keeps the table tidy; whatever it can't
  # see goes inert rather than delivering.
  test "an app's push subscription delivers while its grant is live, alongside the browser's" do
    subscribe_push bearer(@grant)
    users(:kevin).push_subscriptions.create!(push_params(BROWSER))

    assert_equal [ BROWSER, ENDPOINT ].sort, delivered_endpoints.sort
  end

  test "an app's push subscription stops delivering when the user leaves the account" do
    subscribe_push bearer(@grant)
    users(:kevin).push_subscriptions.create!(push_params(BROWSER))

    users(:kevin).deactivate

    assert_equal [ BROWSER ], delivered_endpoints
  end

  test "an app's push subscription stops delivering when the user moves to another identity" do
    subscribe_push bearer(@grant)

    users(:kevin).change_email_address("kevin.elsewhere@example.com")

    assert Identity::AccessToken.exists?(@grant.id)
    assert_empty delivered_endpoints
  end

  test "an app's push subscription stops delivering once its grant lapses, before the sweep" do
    subscribe_push bearer(@grant)

    travel Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.second

    assert Identity::AccessToken.exists?(@grant.id)
    assert_empty delivered_endpoints
  end

  test "a subscription claimed for an app with no grant left never delivers" do
    subscription = users(:kevin).push_subscriptions.create!(push_params(ENDPOINT))
    @grant.destroy

    subscription.claim_for @client

    assert_empty delivered_endpoints
  end

  test "push subscriptions made by a session or a personal access token survive disconnecting" do
    pat = identities(:kevin).access_tokens.create!(permission: :write)
    subscribe_push bearer(pat), endpoint: "https://fcm.googleapis.com/fcm/send/pat-device"

    sign_in_as :kevin
    post user_push_subscriptions_path(users(:kevin)), params: { push_subscription: push_params("https://fcm.googleapis.com/fcm/send/browser") }

    delete my_connected_app_path(@client)

    assert_nil Push::Subscription.find_by!(endpoint: "https://fcm.googleapis.com/fcm/send/pat-device").oauth_client
    assert_nil Push::Subscription.find_by!(endpoint: "https://fcm.googleapis.com/fcm/send/browser").oauth_client
  end

  test "another client's revocation leaves this client's push subscriptions and webhooks alone" do
    other = oauth_clients(:trusted_client)
    other_grant = identities(:kevin).access_tokens.create!(oauth_client: other, permission: :write)
    subscribe_push bearer(@grant)
    webhook = create_webhook bearer(@grant)

    untenanted { post oauth_revocation_path, params: { token: other_grant.token, client_id: other.client_id } }

    assert_not Identity::AccessToken.exists?(other_grant.id)
    assert Push::Subscription.exists?(endpoint: ENDPOINT)
    assert Webhook.exists?(webhook.id)
  end

  test "a webhook created through a grant records who created it and through which app" do
    webhook = create_webhook bearer(@grant)

    assert_equal users(:kevin), webhook.creator
    assert_equal @client, webhook.created_via
  end

  test "a webhook created in a session records its creator and no app" do
    sign_in_as :kevin
    post board_webhooks_path(boards(:writebook)), params: { webhook: { name: "Mine", url: "https://example.com/mine" } }

    webhook = Webhook.find_by!(name: "Mine")
    assert_equal users(:kevin), webhook.creator
    assert_nil webhook.created_via
  end

  test "a webhook created through a grant survives disconnecting, attributed to the person and the app" do
    webhook = create_webhook bearer(@grant)

    sign_in_as :kevin
    delete my_connected_app_path(@client)

    assert Webhook.exists?(webhook.id)

    get board_webhook_path(webhook.board, webhook)
    assert_response :success
    assert_select "p", text: "Created by #{users(:kevin).name} via #{@client.name}"

    get board_webhooks_path(webhook.board)
    assert_response :success
    assert_select "li", text: /via #{Regexp.escape(@client.name)}/
  end

  test "Connected Apps lists the webhooks an app set up, with removal off by default" do
    webhook = create_webhook bearer(@grant)

    sign_in_as :kevin
    get my_connected_apps_path

    assert_response :success
    assert_select "dialog li", text: /#{Regexp.escape(webhook.name)}/
    assert_select "input[type=checkbox][name=remove_webhooks]:not([checked])"
  end

  test "disconnecting with also-remove removes exactly that app's webhooks" do
    app_webhook = create_webhook bearer(@grant)
    other_app_webhook = create_webhook bearer(identities(:kevin).access_tokens.create!(oauth_client: oauth_clients(:trusted_client), permission: :write)), name: "Other app"
    someone_elses_webhook = create_webhook bearer(another_admins_grant), name: "David's"

    sign_in_as :kevin
    post board_webhooks_path(boards(:writebook)), params: { webhook: { name: "By hand", url: "https://example.com/by-hand" } }
    by_hand = Webhook.find_by!(name: "By hand")

    assert_difference -> { Webhook.count }, -1 do
      delete my_connected_app_path(@client), params: { remove_webhooks: "1", webhook_ids: [ app_webhook.id ] }
    end

    assert_not Webhook.exists?(app_webhook.id)
    assert Webhook.exists?(other_app_webhook.id)
    assert Webhook.exists?(someone_elses_webhook.id)
    assert Webhook.exists?(by_hand.id)
    assert_not identities(:kevin).access_tokens.exists?(oauth_client: @client)
  end

  test "also-remove reaches only webhooks the app set up for this person, whatever ids are posted" do
    app_webhook = create_webhook bearer(@grant)
    someone_elses_webhook = create_webhook bearer(another_admins_grant), name: "David's"

    sign_in_as :kevin
    delete my_connected_app_path(@client), params: { remove_webhooks: "1", webhook_ids: [ app_webhook.id, someone_elses_webhook.id, webhooks(:active).id ] }

    assert_not Webhook.exists?(app_webhook.id)
    assert Webhook.exists?(someone_elses_webhook.id)
    assert Webhook.exists?(webhooks(:active).id)
  end

  test "also-remove removes only the webhooks that were listed, not one the app added since" do
    listed = create_webhook bearer(@grant)
    added_since = create_webhook bearer(@grant), name: "Added since"

    sign_in_as :kevin
    delete my_connected_app_path(@client), params: { remove_webhooks: "1", webhook_ids: [ listed.id ] }

    assert_not Webhook.exists?(listed.id)
    assert Webhook.exists?(added_since.id)
  end

  test "a cancelled account's webhooks are neither listed nor removed at revoke time" do
    elsewhere = User.create!(name: "Kevin", identity: identities(:kevin), account: accounts(:initech), role: :admin)
    webhook = Current.set(user: elsewhere) do
      boards(:miltons_wish_list).webhooks.create!(name: "Cancelled feed", url: "https://app.example.com/hooks", created_via: @client)
    end
    accounts(:initech).create_cancellation!(initiated_by: users(:mike))

    sign_in_as :kevin
    get my_connected_apps_path
    assert_select "dialog li", text: /Cancelled feed/, count: 0

    delete my_connected_app_path(@client), params: { remove_webhooks: "1", webhook_ids: [ webhook.id ] }
    assert Webhook.exists?(webhook.id)
  end

  test "disconnecting without also-remove keeps the app's webhooks" do
    webhook = create_webhook bearer(@grant)

    sign_in_as :kevin
    delete my_connected_app_path(@client), params: { webhook_ids: [ webhook.id ] }

    assert Webhook.exists?(webhook.id)
  end

  private
    def bearer(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token.token}" }
    end

    def another_admins_grant
      users(:david).update!(role: :admin)
      identities(:david).access_tokens.create!(oauth_client: @client, permission: :write)
    end

    def push_params(endpoint)
      { endpoint: endpoint, p256dh_key: "p256dh", auth_key: "auth" }
    end

    def subscribe_push(env, endpoint: ENDPOINT)
      post user_push_subscriptions_path(users(:kevin)), params: { push_subscription: push_params(endpoint) }, env: env, as: :json
    end

    def delivered_endpoints
      delivered = []
      pool = mock("web_push_pool")
      pool.stubs(:queue).with { |_payload, subscriptions| delivered = subscriptions.map(&:endpoint) }
      Rails.configuration.x.stubs(:web_push_pool).returns(pool)

      notification = stub(user: users(:kevin).reload, payload: stub(to_h: {}))
      Notification::PushTarget::Web.new(notification).process
      delivered
    end

    def app_subscription
      Push::Subscription.find_by!(endpoint: ENDPOINT)
    end

    def create_webhook(env, name: "App feed")
      post board_webhooks_path(boards(:writebook)), params: { webhook: { name: name, url: "https://app.example.com/hooks" } }, env: env, as: :json
      assert_response :created
      Webhook.find(response.parsed_body["id"])
    end

    def refresh(refresh_token)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id }
      end
    end
end
