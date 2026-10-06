require "test_helper"

# An OAuth grant acts for an app on the user's data. It may not manage the
# user's credentials or consent to apps: anything it minted there would outlive
# disconnecting the app, and anything it removed would be someone else's.
class OauthGrantReachTest < ActionDispatch::IntegrationTest
  setup do
    @grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)
    @bearer = { "HTTP_AUTHORIZATION" => "Bearer #{@grant.token}" }
  end

  test "an OAuth grant can't consent to an app" do
    untenanted do
      post oauth_authorization_path, params: { client_id: oauth_clients(:trusted_client).client_id, redirect_uri: oauth_clients(:trusted_client).redirect_uris.first,
        response_type: "code", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256", scope: "read write", state: "s" },
        env: @bearer, as: :json
    end

    assert_response :forbidden
  end

  test "an OAuth grant can't disconnect an app" do
    other = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:trusted_client))

    delete my_connected_app_path(oauth_clients(:trusted_client)), env: @bearer, as: :json

    assert_response :forbidden
    assert Identity::AccessToken.exists?(other.id)
  end

  test "an OAuth grant can't register a passkey" do
    post my_passkeys_path, params: { passkey: { client_data_json: "{}" } }, env: @bearer, as: :json
    assert_response :forbidden
  end

  test "an OAuth grant can't mint a transfer link" do
    post transfer_token_path, env: @bearer, as: :json

    assert_response :forbidden
  end

  test "an OAuth grant can't change the user's email address" do
    assert_no_emails do
      post user_email_addresses_path(users(:david)), params: { email_address: "app-controlled@example.com" }, env: @bearer, as: :json
    end

    assert_response :forbidden
  end

  test "an OAuth grant can't read or reset the account's join code" do
    code = accounts("37s").join_code.code

    get account_join_code_path, env: @bearer, as: :json
    assert_response :forbidden

    delete account_join_code_path, env: admin_grant, as: :json
    assert_response :forbidden
    assert_equal code, accounts("37s").join_code.reload.code
  end

  test "an OAuth grant can't export the account, which carries its join code and webhook credentials" do
    assert_no_difference -> { Account::Export.count } do
      post account_exports_path, env: admin_grant, as: :json
    end
    assert_response :forbidden

    export = Account::Export.create!(account: accounts("37s"), user: users(:kevin))
    get account_export_path(export), env: admin_grant, as: :json
    assert_response :forbidden
  end

  test "an OAuth grant reads webhooks without their credentials" do
    webhook = webhooks(:active)

    get board_webhooks_path(webhook.board), env: admin_grant, as: :json
    assert_response :success
    assert_equal webhook.id, @response.parsed_body.first["id"]
    assert_webhook_credentials_withheld @response.parsed_body.first

    get board_webhook_path(webhook.board, webhook), env: admin_grant, as: :json
    assert_response :success
    assert_webhook_credentials_withheld @response.parsed_body

    put board_webhook_path(webhook.board, webhook), params: { webhook: { name: "Renamed" } }, env: admin_grant, as: :json
    assert_response :success
    assert_equal "Renamed", @response.parsed_body["name"]
    assert_webhook_credentials_withheld @response.parsed_body

    post board_webhook_activation_path(webhook.board, webhook), env: admin_grant, as: :json
    assert_response :created
    assert_webhook_credentials_withheld @response.parsed_body
  end

  test "an OAuth grant gets a webhook's credentials once, when it creates it" do
    post board_webhooks_path(boards(:writebook)), params: { webhook: { name: "App", url: "https://app.example.com/hooks" } }, env: admin_grant, as: :json

    assert_response :created
    webhook = Webhook.find(@response.parsed_body["id"])
    assert_equal webhook.signing_secret, @response.parsed_body["signing_secret"]
    assert_equal "https://app.example.com/hooks", @response.parsed_body["payload_url"]

    get board_webhook_path(webhook.board, webhook), env: admin_grant, as: :json
    assert_webhook_credentials_withheld @response.parsed_body
  end

  test "a personal access token still reads the join code and webhook credentials" do
    webhook = webhooks(:active)
    pat = { "HTTP_AUTHORIZATION" => "Bearer #{identities(:kevin).access_tokens.create!(permission: :read).token}" }

    get account_join_code_path, env: pat, as: :json
    assert_response :success
    assert_equal accounts("37s").join_code.code, @response.parsed_body["code"]

    get board_webhook_path(webhook.board, webhook), env: pat, as: :json
    assert_response :success
    assert_equal webhook.signing_secret, @response.parsed_body["signing_secret"]
    assert_equal webhook.url, @response.parsed_body["payload_url"]
  end

  test "a personal access token still manages personal access tokens" do
    pat = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }

    get my_access_tokens_path, env: pat, as: :json

    assert_response :success
  end

  private
    def admin_grant
      token = identities(:kevin).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write).token
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end

    def assert_webhook_credentials_withheld(json)
      assert_not json.key?("signing_secret"), "expected no signing_secret in #{json.keys}"
      assert_not json.key?("payload_url"), "expected no payload_url in #{json.keys}"
    end
end
