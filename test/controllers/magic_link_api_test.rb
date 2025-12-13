require "test_helper"

class MagicLinkApiTest < ActionDispatch::IntegrationTest
  test "request a magic link" do
    untenanted do
      post session_path(format: :json), params: { email_address: identities(:david).email_address }
      assert_response :created
    end
  end

  test "magic link consumption" do
    identity = identities(:david)
    magic_link = identity.send_magic_link
    pending_token = pending_authentication_token_for(identity.email_address)

    untenanted do
      post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: pending_token }
      assert_response :success
      assert @response.parsed_body["session_token"].present?
    end
  end

  test "full JSON authentication flow with pending_authentication_token" do
    identity = identities(:david)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      assert_response :created
      pending_token = @response.parsed_body["pending_authentication_token"]
      assert pending_token.present?

      magic_link = MagicLink.last
      post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: pending_token }
      assert_response :success
      assert @response.parsed_body["session_token"].present?
    end
  end

  test "magic link consumption without pending_authentication_token returns unauthorized" do
    identity = identities(:david)
    magic_link = identity.send_magic_link

    untenanted do
      post session_magic_link_path(format: :json), params: { code: magic_link.code }
      assert_response :unauthorized
      assert_equal "Enter your email address to sign in.", @response.parsed_body["message"]
    end
  end

  test "magic link consumption with invalid code via JSON" do
    identity = identities(:david)
    pending_token = pending_authentication_token_for(identity.email_address)

    untenanted do
      post session_magic_link_path(format: :json), params: { code: "INVALID", pending_authentication_token: pending_token }
      assert_response :unauthorized
      assert_equal "Try another code.", @response.parsed_body["message"]
    end
  end

  test "magic link consumption with cross-user code via JSON returns unauthorized" do
    identity = identities(:david)
    other_identity = identities(:jason)
    magic_link = other_identity.send_magic_link
    pending_token = pending_authentication_token_for(identity.email_address)

    untenanted do
      post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: pending_token }
      assert_response :unauthorized
      assert_equal "Authentication failed. Please try again.", @response.parsed_body["message"]
    end
  end

  test "magic link consumption with expired pending_authentication_token" do
    identity = identities(:david)
    magic_link = identity.send_magic_link

    expired_token = nil
    travel_to 15.minutes.ago do
      expired_token = pending_authentication_token_for(identity.email_address)
    end

    untenanted do
      post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: expired_token }
      assert_response :unauthorized
      assert_equal "Enter your email address to sign in.", @response.parsed_body["message"]
    end
  end

  test "create session for new user via JSON" do
    new_email = "new-user-#{SecureRandom.hex(6)}@example.com"

    untenanted do
      assert_difference -> { Identity.count }, 1 do
        assert_difference -> { MagicLink.count }, 1 do
          post session_path(format: :json), params: { email_address: new_email }
        end
      end
      assert_response :created
      assert @response.parsed_body["pending_authentication_token"].present?
      assert MagicLink.last.for_sign_up?
    end
  end

  test "create session with invalid email via JSON" do
    untenanted do
      assert_no_difference -> { Identity.count } do
        post session_path(format: :json), params: { email_address: "not-a-valid-email" }
      end
      assert_response :unprocessable_entity
    end
  end

  private
    def pending_authentication_token_for(email_address)
      Rails.application.message_verifier(:pending_authentication).generate(email_address, expires_in: 10.minutes)
    end
end
