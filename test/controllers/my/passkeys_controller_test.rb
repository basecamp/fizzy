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

  test "malformed attestation is rejected with a redirect, not a 500" do
    challenge = request_webauthn_challenge(purpose: "registration")
    params = build_attestation_params(challenge: challenge)
    params[:passkey][:attestation_object] = "this-is-not-a-valid-attestation-object"

    assert_no_difference -> { identities(:kevin).passkeys.count } do
      post my_passkeys_path, params: params
    end

    assert_redirected_to my_passkeys_path
    assert_equal "We couldn't register that passkey. Please try again.", flash[:alert]
  end

  test "re-registering an existing credential is rejected with a friendly message" do
    challenge = request_webauthn_challenge(purpose: "registration")
    credential_id = SecureRandom.random_bytes(32)

    post my_passkeys_path, params: build_attestation_params(challenge: challenge, credential_id: credential_id)
    assert_response :redirect

    challenge = request_webauthn_challenge(purpose: "registration")
    assert_no_difference -> { ActionPack::Passkey.count } do
      post my_passkeys_path, params: build_attestation_params(challenge: challenge, credential_id: credential_id)
    end

    assert_redirected_to my_passkeys_path
    assert_equal "That passkey is already registered.", flash[:alert]
  end
end
