require "test_helper"

# A personal access token takes one of two forms: issued by the personal access
# client, as every token made from now on is, or with no client at all, as every
# token made before that client existed is, and as production code that predates
# it still makes them. Each rule that sets personal tokens apart from OAuth
# grants must hold for both alike, so every test here runs once per form.
class PersonalAccessTokenFormsTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  ENDPOINT = "https://fcm.googleapis.com/fcm/send/cli-device"

  { "client-less" => nil, "client-backed" => :personal_access }.each do |form, issuer|
    test "a #{form} personal access token is personal, and no app's" do
      token = personal_token(issuer)

      assert token.personal?
      assert_not token.oauth?
      assert_nil token.connected_app
      assert_includes Identity::AccessToken.personal, token
      assert_not_includes Identity::AccessToken.oauth, token
    end

    test "a #{form} personal access token has the personal prefix, its plaintext, no expiry and no refresh token" do
      token = personal_token(issuer)

      assert token.raw_token.start_with?("fizzy_pat_")
      assert_equal token.raw_token, token.reload.token
      assert_nil token.expires_at
      assert_nil token.refresh_token_digest
      assert_nil token.raw_refresh_token
    end

    test "a #{form} personal access token is honored while OAuth is dark" do
      token = personal_token(issuer)

      with_oauth_availability acceptance: false do
        get user_path(users(:david)), env: bearer(token), as: :json
      end

      assert_response :success
    end

    # Shipped clients (fizzy-cli, the native apps) have always had a 401 for a
    # read-only personal token's write. Only an app's grant gets the 403.
    test "a #{form} read-only personal access token's write is a 401, as shipped clients expect" do
      token = personal_token(issuer)

      post boards_path(format: :json), params: { board: { name: "Not made" } }, env: bearer(token)

      assert_response :unauthorized
      assert_match 'error="insufficient_scope"', response.headers["WWW-Authenticate"]
      assert_match 'scope="write"', response.headers["WWW-Authenticate"]
    end

    test "a #{form} personal access token never lapses, however long it sits idle" do
      token = personal_token(issuer)

      travel Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.day
      assert_not token.lapsed?
      assert_not_includes Identity::AccessToken.lapsed, token

      Identity::AccessToken.cleanup
      assert Identity::AccessToken.exists?(token.id)

      get user_path(users(:david)), env: bearer(token), as: :json
      assert_response :success
    end

    test "a #{form} personal access token is revoked by whoever presents it" do
      [ {}, { client_id: oauth_clients(:mcp_client).client_id }, { client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID } ].each do |params|
        token = personal_token(issuer)

        untenanted { post oauth_revocation_path, params: { token: token.raw_token, **params } }

        assert_response :success
        assert_not Identity::AccessToken.exists?(token.id), "expected revocation with #{params}"
      end
    end

    test "a #{form} personal access token gets no refresh at the token endpoint" do
      token = personal_token(issuer)

      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: token.raw_token, client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID }
      end

      assert_response :bad_request
      assert_equal "unauthorized_client", response.parsed_body["error"]

      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: token.raw_token, client_id: oauth_clients(:mcp_client).client_id }
      end

      assert_response :bad_request
      assert_equal "invalid_grant", response.parsed_body["error"]
      assert_equal token.token_digest, token.reload.token_digest
    end

    test "a #{form} personal access token manages personal access tokens" do
      token = personal_token(issuer, permission: :write)

      untenanted do
        post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "read" } }, env: bearer(token), as: :json
        assert_response :created

        get my_access_tokens_path, env: bearer(token), as: :json
        assert_response :success
        assert_includes response.parsed_body.pluck("id"), token.id
      end
    end

    test "a #{form} personal access token is listed with personal access tokens, and not under Connected Apps" do
      token = personal_token(issuer, description: "Shell script")
      sign_in_as :david

      untenanted { get my_access_tokens_path }
      assert_in_body "Shell script"

      get my_connected_apps_path
      assert_response :success
      assert_not_in_body "Shell script"
      assert_not_in_body "Personal Access Tokens"

      delete my_connected_app_path(oauth_clients(:personal_access))
      assert_response :not_found
      assert Identity::AccessToken.exists?(token.id)
    end

    test "a #{form} personal access token is revoked from the personal access tokens page" do
      token = personal_token(issuer)
      sign_in_as :david

      untenanted { delete my_access_token_path(token), as: :json }

      assert_response :no_content
      assert_not Identity::AccessToken.exists?(token.id)
    end

    test "a webhook a #{form} personal access token sets up is attributed to the person alone" do
      users(:kevin).update!(role: :admin)
      token = personal_token(issuer, identity: :kevin, permission: :write)

      post board_webhooks_path(boards(:writebook)), params: { webhook: { name: "Feed", url: "https://app.example.com/hooks" } }, env: bearer(token), as: :json

      assert_response :created
      webhook = Webhook.find(response.parsed_body["id"])
      assert_equal users(:kevin), webhook.creator
      assert_nil webhook.created_via
    end

    test "a push subscription a #{form} personal access token registers is no app's, and survives the token" do
      stub_web_push_dns_resolution
      token = personal_token(issuer, identity: :kevin, permission: :write)

      post user_push_subscriptions_path(users(:kevin)), params: { push_subscription: { endpoint: ENDPOINT, p256dh_key: "p256dh", auth_key: "auth" } }, env: bearer(token), as: :json

      assert_response :created
      subscription = Push::Subscription.find_by!(endpoint: ENDPOINT)
      assert_nil subscription.oauth_client
      assert_includes Push::Subscription.deliverable_to(users(:kevin)), subscription

      token.destroy
      assert Push::Subscription.exists?(subscription.id)
    end

    test "a #{form} personal access token reaches an account only while its user is active there" do
      token = personal_token(issuer)

      get boards_path, env: bearer(token), as: :json
      assert_response :success

      users(:david).deactivate

      get boards_path, env: bearer(token), as: :json
      assert_response :forbidden
    end

    test "a #{form} personal access token without a digest is found by its plaintext and digested" do
      token = personal_token(issuer)
      token.update_columns token_digest: nil

      assert_equal token, Identity::AccessToken.find_honored(token.raw_token)
      assert_equal TokenDigester.digest(token.raw_token), token.reload.token_digest
    end

    test "issuing or revoking a #{form} personal access token leaves the issuer's retention clock alone" do
      assert_no_changes -> { oauth_clients(:personal_access).reload.updated_at } do
        personal_token(issuer).destroy
      end
    end
  end

  test "a personal access token made from the page is issued by the personal access client" do
    sign_in_as :david

    untenanted { post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "write" } }, as: :json }

    assert_response :created
    assert_equal %w[ created_at description id permission token ], response.parsed_body.keys.sort
    assert_equal oauth_clients(:personal_access), Identity::AccessToken.find(response.parsed_body["id"]).oauth_client
  end

  test "the authorization endpoint refuses the personal access client" do
    sign_in_as :david

    untenanted do
      get new_oauth_authorization_path, params: { client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID, response_type: "code",
        redirect_uri: "http://127.0.0.1:8888/callback", code_challenge: "challenge", code_challenge_method: "S256", state: "state" }
    end

    assert_response :bad_request
    assert_equal "unauthorized_client", response.parsed_body["error"]
  end

  test "the token endpoint refuses the personal access client the code grant" do
    untenanted do
      post oauth_token_path, params: { grant_type: "authorization_code", code: "code", code_verifier: "verifier",
        redirect_uri: "http://127.0.0.1:8888/callback", client_id: Oauth::Client::PERSONAL_ACCESS_CLIENT_ID }
    end

    assert_response :bad_request
    assert_equal "unauthorized_client", response.parsed_body["error"]
  end

  private
    def personal_token(issuer, identity: :david, **attributes)
      identities(identity).access_tokens.create!(oauth_client: issuer && oauth_clients(issuer), permission: :read, **attributes)
    end

    def bearer(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token.raw_token}" }
    end
end
