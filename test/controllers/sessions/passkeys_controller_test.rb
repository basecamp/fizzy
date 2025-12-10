require "test_helper"

class Sessions::PasskeysControllerTest < ActionDispatch::IntegrationTest
  test "create with invalid credential redirects with error" do
    untenanted do
      # First visit login page to get the challenge
      get new_session_url

      # Then try to authenticate with invalid credential
      post session_passkey_url, params: { credential: '{"id": "invalid"}' }

      assert_redirected_to new_session_url(script_name: nil)
      assert_equal "Authentication failed. Try again or use email.", flash[:alert]
    end
  end

  test "create with non-existent passkey redirects with error" do
    untenanted do
      get new_session_url

      # Simulate a credential that doesn't exist in our database
      post session_passkey_url, params: {
        credential: JSON.generate({
          id: "non-existent-passkey-id",
          rawId: Base64.urlsafe_encode64("non-existent-passkey-id", padding: false),
          type: "public-key",
          response: {
            clientDataJSON: Base64.urlsafe_encode64("{}", padding: false),
            authenticatorData: Base64.urlsafe_encode64("fake-auth-data", padding: false),
            signature: Base64.urlsafe_encode64("fake-signature", padding: false)
          }
        })
      }

      assert_redirected_to new_session_url(script_name: nil)
      assert_equal "Authentication failed. Try again or use email.", flash[:alert]
    end
  end
end
