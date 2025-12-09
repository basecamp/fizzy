require "test_helper"

class Signup::PasskeysControllerTest < ActionDispatch::IntegrationTest
  test "create with invalid credential shows error" do
    untenanted do
      # Visit signup page to get the challenge
      get new_signup_url

      post signup_passkey_path, params: {
        email_address: "test@example.com",
        credential: '{"id": "invalid"}'
      }

      assert_redirected_to new_signup_url(script_name: nil)
      assert_equal "Could not register passkey. Please try again.", flash[:alert]
    end
  end

  test "create with invalid email shows error" do
    untenanted do
      get new_signup_url

      post signup_passkey_path, params: {
        email_address: "not-an-email",
        credential: '{"id": "test"}'
      }

      assert_redirected_to new_signup_url(script_name: nil)
      assert_equal "Please enter a valid email address.", flash[:alert]
    end
  end
end
