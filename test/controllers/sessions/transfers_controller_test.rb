require "test_helper"

class Sessions::TransfersControllerTest < ActionDispatch::IntegrationTest
  test "show renders when not signed in" do
    untenanted do
      get session_transfer_path("some-token")

      assert_response :success
    end
  end

  test "update establishes a session when the code is valid" do
    identity = identities(:david)

    untenanted do
      put session_transfer_path(identity.transfer_id)

      assert_redirected_to session_menu_url(script_name: nil)
      assert parsed_cookies.signed[:session_token]
    end
  end

  test "a transfer token is single-use: a zero-cookie replay is rejected" do
    identity = identities(:david)
    transfer_id = identity.transfer_id

    untenanted do
      put session_transfer_path(transfer_id)
      assert_redirected_to session_menu_url(script_name: nil)
    end

    # Replay the same link from a fresh, cookieless client, as the reported
    # redemptions did. The token is already consumed, so it is rejected.
    reset!
    untenanted do
      put session_transfer_path(transfer_id)
      assert_response :bad_request
    end
  end
end
