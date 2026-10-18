require "test_helper"

# Pins how shipped clients (the CLI, scripts holding a personal access token, and the
# native apps sending the session_token cookie) authenticate today. Changes to the
# authentication stack must keep these green, or change them deliberately.
class ShippedClientAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @write_token = identity_access_tokens(:davids_api_token)
    @read_token = identity_access_tokens(:jasons_api_token)
  end

  # Authentication#authenticate_by_bearer_token resolves the token to an Identity, not a User,
  # so one token reaches every account the identity has a user in.
  test "a personal access token reaches every account its identity belongs to" do
    accounts(:initech).users.create!(identity: identities(:david), name: "David", role: :member)

    get boards_path(format: :json), env: bearer(@write_token)
    assert_response :ok

    get boards_path(format: :json, script_name: "/#{accounts(:initech).external_account_id}"), env: bearer(@write_token)
    assert_response :ok

    untenanted { get my_identity_path(format: :json), env: bearer(@write_token) }
    assert_response :ok
    assert_equal [ accounts("37s"), accounts(:initech) ].map(&:name).sort,
      response.parsed_body["accounts"].map { it["name"] }.sort
  end

  # Authorization#ensure_can_access_account still applies to token-authenticated requests.
  test "a personal access token is forbidden in an account its identity has no user in" do
    get boards_path(format: :json, script_name: "/#{accounts(:acme).external_account_id}"), env: bearer(@write_token)
    assert_response :forbidden
  end

  # Identity::AccessToken#allows?: GET and HEAD for any token, everything else needs write.
  test "a read token may read but not write" do
    board = boards(:writebook)

    get boards_path(format: :json), env: bearer(@read_token)
    assert_response :ok

    head boards_path(format: :json), env: bearer(@read_token)
    assert_response :ok

    assert_no_difference -> { Board.count } do
      post boards_path(format: :json), params: { board: { name: "Read token board" } }, env: bearer(@read_token)
    end
    assert_response :unauthorized

    patch board_path(board, format: :json), params: { board: { name: "Read token rename" } }, env: bearer(@read_token)
    assert_response :unauthorized
    assert_not_equal "Read token rename", board.reload.name

    assert_no_difference -> { Board.count } do
      delete board_path(board, format: :json), env: bearer(@read_token)
    end
    assert_response :unauthorized
  end

  test "a write token may write" do
    assert_difference -> { Board.count }, +1 do
      post boards_path(format: :json), params: { board: { name: "Write token board" } }, env: bearer(@write_token)
    end
    assert_response :created
  end

  # Identity.find_by_permissable_access_token looks a token up by value alone: no expiry.
  test "a personal access token does not expire" do
    @write_token.update_columns(created_at: 10.years.ago, updated_at: 10.years.ago)

    travel 10.years do
      get boards_path(format: :json), env: bearer(@write_token)
      assert_response :ok
    end
  end

  # Authentication#bearer_token_authenticatable_request? limits the token path to JSON.
  test "a personal access token does not authenticate a non-JSON request" do
    get boards_path, env: bearer(@write_token)
    assert_response :unauthorized

    get board_path(boards(:writebook)), env: bearer(@write_token), headers: { "Accept" => "text/html" }
    assert_response :unauthorized
  end

  # Authentication#resume_session: the native apps send the session_token returned by the
  # JSON magic-link sign-in back as a raw Cookie header on JSON requests.
  test "a session_token cookie authenticates a JSON request" do
    session_token = sign_in_over_json(identities(:david))
    cookies.delete :session_token

    get boards_path(format: :json), headers: { "Cookie" => "session_token=#{session_token}" }
    assert_response :ok

    untenanted { get my_identity_path(format: :json), headers: { "Cookie" => "session_token=#{session_token}" } }
    assert_response :ok
    assert_equal identities(:david).id, response.parsed_body["id"]
  end

  # Authentication#request_authentication redirects to login whatever the format.
  test "a JSON request without credentials redirects to login" do
    get boards_path(format: :json)
    assert_response :found
    assert_redirected_to new_session_path(script_name: nil)

    get boards_path(format: :json), headers: { "Cookie" => "session_token=nonsense" }
    assert_response :found
    assert_redirected_to new_session_path(script_name: nil)
  end

  private
    def bearer(access_token)
      { "HTTP_AUTHORIZATION" => "Bearer #{access_token.token}" }
    end

    def sign_in_over_json(identity)
      untenanted do
        post session_path(format: :json), params: { email_address: identity.email_address }
        post session_magic_link_path(format: :json), params: { code: identity.magic_links.order(:created_at).last.code,
          pending_authentication_token: response.parsed_body["pending_authentication_token"] }
      end
      assert_response :success

      response.parsed_body["session_token"].tap { assert it.present? }
    end
end
