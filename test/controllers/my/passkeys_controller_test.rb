require "test_helper"

class My::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include WebauthnTestHelper

  setup do
    sign_in_as :kevin
  end

  test "index" do
    get my_passkeys_path
    assert_response :success
  end

  test "register a passkey" do
    challenge = request_webauthn_challenge(purpose: "registration")

    assert_difference -> { identities(:kevin).passkeys.count }, 1 do
      post my_passkeys_path, params: build_attestation_params(challenge: challenge)
    end

    passkey = identities(:kevin).passkeys.order(created_at: :desc).first
    assert_redirected_to edit_my_passkey_path(passkey, created: true)
    assert_equal [ "internal" ], passkey.transports
  end
end
