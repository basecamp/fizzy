require "test_helper"

class My::AccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index renders untenanted" do
    identities(:kevin).access_tokens.create!(description: "Fizzy CLI", permission: "read")

    untenanted do
      get my_access_tokens_path

      assert_response :success
      assert_in_body session_menu_path
      assert_not_in_body user_path(users(:kevin))
    end
  end

  test "create new token" do
    get my_access_tokens_path
    assert_response :success
    assert_in_body user_path(users(:kevin))

    get new_my_access_token_path
    assert_response :success
    assert_select "meta[name=turbo-cache-control][content=no-cache]"

    assert_changes -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "read" } }
    end

    assert_response :created
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_revealed identities(:kevin).access_tokens.order(:created_at).last
  end

  test "create new token from the form reveals it in a turbo stream" do
    assert_changes -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "write" } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_turbo_stream action: :replace, target: "new_access_token"
    assert_revealed identities(:kevin).access_tokens.order(:created_at).last
  end

  # Only the token's digest is ever looked up, so the response that created it
  # is the one place it's shown. No page can show it again.
  test "a created token is revealed once, and no page shows it again" do
    post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "read" } }
    raw_token = token_in_body
    access_token = identities(:kevin).access_tokens.order(:created_at).last

    get "/my/access_tokens/#{access_token.id}"
    assert_response :not_found

    get my_access_tokens_path
    assert_response :success
    assert_not_includes response.body, raw_token
  end

  test "create new token via JSON with session" do
    assert_difference -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "write" } }, as: :json
    end
    assert_response :created
    assert_equal "no-store", response.headers["Cache-Control"]
    body = @response.parsed_body
    assert body["id"].present?
    assert_equal TokenDigester.digest(body["token"]), Identity::AccessToken.find(body["id"]).token_digest
    assert_equal "Fizzy CLI", body["description"]
    assert_equal "write", body["permission"]
    assert body["created_at"].present?
  end

  test "create new token via JSON with bearer token" do
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).raw_token}" }

    assert_difference -> { identities(:david).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "read" } }, env: bearer_token, as: :json
    end
    assert_response :created
    body = @response.parsed_body
    assert body["token"].present?
    assert_equal "Fizzy CLI", body["description"]
    assert_equal "read", body["permission"]
  end

  # A personal access token outlives the app that minted it: it isn't listed
  # under Connected Apps and survives a disconnect. So an OAuth grant may not
  # manage personal access tokens at all.
  test "an OAuth grant can't create, list or revoke personal access tokens" do
    sign_out
    grant = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }

    assert_no_difference -> { identities(:david).access_tokens.count } do
      post my_access_tokens_path, params: { access_token: { description: "Escape hatch", permission: "write" } }, env: bearer_token, as: :json
    end
    assert_response :forbidden

    get my_access_tokens_path, env: bearer_token, as: :json
    assert_response :forbidden

    assert_no_difference -> { identities(:david).access_tokens.count } do
      delete my_access_token_path(identity_access_tokens(:davids_api_token)), env: bearer_token, as: :json
    end
    assert_response :forbidden
  end

  test "cannot create new token via JSON with read-only bearer token" do
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:jasons_api_token).raw_token}" }

    assert_no_difference -> { identities(:jason).access_tokens.count } do
      post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "read" } }, env: bearer_token, as: :json
    end
    assert_response :unauthorized
  end

  test "index as JSON" do
    get my_access_tokens_path, as: :json
    assert_response :success

    body = @response.parsed_body
    assert_kind_of Array, body
  end

  test "index as JSON with bearer token and no account scope" do
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).raw_token}" }

    untenanted do
      get my_access_tokens_path, as: :json, env: bearer_token
    end

    assert_response :success
    assert_kind_of Array, @response.parsed_body
  end

  test "destroy as JSON" do
    token = identities(:kevin).access_tokens.create!(description: "To delete", permission: "read")

    assert_difference -> { identities(:kevin).access_tokens.count }, -1 do
      delete my_access_token_path(token), as: :json
    end

    assert_response :no_content
  end

  private
    def token_in_body
      response.body[/value="(fizzy_pat_\w+)"/, 1]
    end

    # Temporary, so Turbo's snapshot cache doesn't keep the token for Back to restore.
    def assert_revealed(access_token)
      assert_equal access_token.token_digest, TokenDigester.digest(token_in_body)
      assert_match(/<article id="new_access_token"[^>]* data-turbo-temporary[ >]/, response.body)
    end
end
