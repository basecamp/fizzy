require "test_helper"

class Sessions::RelaysControllerTest < ActionDispatch::IntegrationTest
  test "show renders when not signed in" do
    get session_relay_url("some-token")

    assert_response :success
  end

  test "update establishes a session when the code is valid" do
    user = users(:david)

    put session_relay_url(user.relay_id)

    assert_redirected_to root_url
    assert parsed_cookies.signed[:session_token]
  end
end
