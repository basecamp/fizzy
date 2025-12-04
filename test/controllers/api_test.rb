require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @davids_bearer_token = bearer_token_env(identity_access_tokens(:davids_api_token).token)
    @jasons_bearer_token = bearer_token_env(identity_access_tokens(:jasons_api_token).token)
  end

  test "authenticate with valid access token" do
    get boards_path(format: :json), env: @davids_bearer_token
    assert_response :success
  end

  test "fail to authenticate with invalid access token" do
    get boards_path(format: :json), env: bearer_token_env("nonsense")
    assert_response :unauthorized
  end

  test "changing data requires a write-endowed access token" do
    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @jasons_bearer_token
    assert_response :unauthorized

    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @davids_bearer_token
    assert_response :success
  end

  test "get boards" do
    get boards_path(format: :json), env: @davids_bearer_token
    assert_equal users(:david).boards.count, @response.parsed_body.count

    get board_path(boards(:writebook), format: :json), env: @davids_bearer_token
    assert_equal boards(:writebook).name, @response.parsed_body["name"]
  end

  test "create board" do
    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @davids_bearer_token
    assert_equal board_path(Board.last, format: :json), @response.headers["Location"]

    get board_path(Board.last, format: :json), env: @davids_bearer_token
    assert_equal "My new board", @response.parsed_body["name"]
  end

  test "create card" do
    post board_cards_path(boards(:writebook), format: :json),
      params: { card: { title: "My new card", description: "Big if true", tag_ids: [ tags(:web).id, tags(:mobile).id ] } },
      env: @davids_bearer_token

    assert_equal card_path(Card.last, format: :json), @response.headers["Location"]

    new_card = Card.last
    get card_path(new_card, format: :json), env: @davids_bearer_token
    assert_equal "My new card", @response.parsed_body["title"]
    assert_equal "Big if true", @response.parsed_body["description"]
    assert_equal [ tags(:web).title, tags(:mobile).title ].sort, @response.parsed_body["tags"]
  end

  test "get tags" do
    tags = users(:david).account.tags.all.alphabetically

    get tags_path(format: :json), env: @davids_bearer_token
    assert_equal tags.count, @response.parsed_body.count
    assert_equal tags.pluck(:title), @response.parsed_body.pluck("title")
  end

  test "get users" do
    get users_path(format: :json), env: @davids_bearer_token
    assert_equal users(:david).account.users.active.count, @response.parsed_body.count

    get user_path(users(:david), format: :json), env: @davids_bearer_token
    assert_equal users(:david).name, @response.parsed_body["name"]
  end

  test "get identity" do
    identity = identities(:david)

    get identity_path(format: :json), env: @davids_bearer_token
    assert_response :success # Fix 302 redirect
    assert_equal identity.accounts.count, @response.parsed_body["accounts"].count
  end

  private
    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end
end
