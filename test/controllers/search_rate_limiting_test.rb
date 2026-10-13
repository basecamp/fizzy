require "test_helper"

class SearchRateLimitingTest < ActionDispatch::IntegrationTest
  test "a token's search under the hourly limit goes through" do
    Rails.cache.stubs(:increment).returns(SearchRateLimiting::SEARCHES_PER_HOUR)

    get cards_path(format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:davids_api_token)

    assert_response :success
  end

  test "a token's search over the hourly limit gets a 429 with Retry-After" do
    Rails.cache.stubs(:increment).returns(SearchRateLimiting::SEARCHES_PER_HOUR + 1)

    get cards_path(format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:davids_api_token)

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_equal "Too many searches. Retry after 60 seconds.", response.parsed_body["error"]
  end

  test "the search endpoint shares the same limit" do
    Rails.cache.stubs(:increment).returns(SearchRateLimiting::SEARCHES_PER_HOUR + 1)

    get search_path(format: :json), params: { q: "haggis" }, headers: bearer_token_header(:davids_api_token)

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "a board filtered by terms shares the same limit" do
    Rails.cache.stubs(:increment).returns(SearchRateLimiting::SEARCHES_PER_HOUR + 1)

    get board_path(boards(:writebook), format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:davids_api_token)

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "card lists, searches and boards count against one hourly budget per user" do
    Rails.cache.expects(:increment).with("rate-limit:searches:#{users(:david).cache_key}", 1, expires_in: 1.hour).times(3).returns(1)

    get cards_path(format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:davids_api_token)
    assert_response :success

    get search_path(format: :json), params: { q: "haggis" }, headers: bearer_token_header(:davids_api_token)
    assert_response :success

    get board_path(boards(:writebook), format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:davids_api_token)
    assert_response :success
  end

  test "another user keeps their own budget" do
    Rails.cache.stubs(:increment).returns(1)
    Rails.cache.stubs(:increment).with("rate-limit:searches:#{users(:david).cache_key}", 1, expires_in: 1.hour).returns(SearchRateLimiting::SEARCHES_PER_HOUR + 1)

    get cards_path(format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:davids_api_token)
    assert_response :too_many_requests

    get cards_path(format: :json), params: { terms: [ "haggis" ] }, headers: bearer_token_header(:jasons_api_token)
    assert_response :success
  end

  test "a card list without terms is not counted" do
    Rails.cache.expects(:increment).never

    get cards_path(format: :json), headers: bearer_token_header(:davids_api_token)

    assert_response :success
  end

  test "searches from a signed-in session are not counted" do
    sign_in_as :david
    Rails.cache.expects(:increment).never

    get cards_path, params: { terms: [ "haggis" ] }
    assert_response :success

    get search_path, params: { q: "haggis" }
    assert_response :success
  end

  private
    def bearer_token_header(fixture)
      { "Authorization" => "Bearer #{identity_access_tokens(fixture).token}" }
    end
end
