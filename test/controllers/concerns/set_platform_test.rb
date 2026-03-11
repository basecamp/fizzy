require "test_helper"

class SetPlatformTest < ActionDispatch::IntegrationTest
  DESKTOP_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  NATIVE_IOS_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Hotwire Native iOS/1.0"

  test "uses the request user agent by default" do
    sign_in_as :david

    get board_path(boards(:writebook)), headers: { "User-Agent" => DESKTOP_UA }
    assert_match 'data-platform="desktop web"', response.body
  end

  test "prefers x_user_agent cookie over request user agent" do
    sign_in_as :david

    cookies[:x_user_agent] = NATIVE_IOS_UA
    get board_path(boards(:writebook)), headers: { "User-Agent" => DESKTOP_UA }
    assert_match 'data-platform="native ios"', response.body
  end
end
