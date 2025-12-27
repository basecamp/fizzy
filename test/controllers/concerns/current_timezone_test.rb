require "test_helper"

class CurrentTimezoneTest < ActionDispatch::IntegrationTest
  test "includes the timezone cookie in the ETag" do
    cookies[:timezone] = "America/New_York"
    get user_avatar_path(users(:kevin))
    etag = response.headers.fetch("ETag")

    get user_avatar_path(users(:kevin)), headers: { "If-None-Match" => etag }
    assert_equal 304, response.status

    cookies[:timezone] = "America/Los_Angeles"
    get user_avatar_path(users(:kevin)), headers: { "If-None-Match" => etag }
    assert_response :success
    assert_not_equal etag, response.headers.fetch("ETag")
  end
end
