require "test_helper"

class Sessions::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:kevin)
    @private_key = OpenSSL::PKey::EC.generate("prime256v1")

    @credential = @identity.credentials.create!(
      name: "Test Passkey",
      credential_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
      public_key: @private_key.public_to_der,
      sign_count: 0,
      transports: [ "internal" ]
    )
  end

  test "successful authentication" do
    untenanted do
      get new_session_url
      challenge = session[:webauthn_challenge]

      post session_passkey_url, params: assertion_params(challenge: challenge)

      assert_response :redirect
      assert cookies[:session_token].present?
      assert_redirected_to landing_path
    end
  end

  test "updates sign count" do
    untenanted do
      get new_session_url
      challenge = session[:webauthn_challenge]

      post session_passkey_url, params: assertion_params(challenge: challenge, sign_count: 1)

      assert_equal 1, @credential.reload.sign_count
    end
  end

  test "rejects invalid signature" do
    untenanted do
      get new_session_url
      challenge = session[:webauthn_challenge]

      params = assertion_params(challenge: challenge)
      params[:response][:signature] = Base64.urlsafe_encode64("invalid", padding: false)

      post session_passkey_url, params: params

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
      assert_equal "That passkey didn't work. Try again.", flash[:alert]
    end
  end

  test "rejects unknown credential" do
    untenanted do
      get new_session_url

      post session_passkey_url, params: {
        credential_id: "nonexistent",
        response: {
          client_data_json: Base64.urlsafe_encode64("{}", padding: false),
          authenticator_data: Base64.urlsafe_encode64("x", padding: false),
          signature: Base64.urlsafe_encode64("x", padding: false)
        }
      }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "successful authentication via JSON" do
    untenanted do
      get new_session_url
      challenge = session[:webauthn_challenge]

      post session_passkey_url(format: :json), params: assertion_params(challenge: challenge)

      assert_response :success
      assert @response.parsed_body["session_token"].present?
    end
  end

  test "failed authentication via JSON" do
    untenanted do
      get new_session_url

      post session_passkey_url(format: :json), params: {
        credential_id: "nonexistent",
        response: {
          client_data_json: Base64.urlsafe_encode64("{}", padding: false),
          authenticator_data: Base64.urlsafe_encode64("x", padding: false),
          signature: Base64.urlsafe_encode64("x", padding: false)
        }
      }

      assert_response :unauthorized
      assert_equal "That passkey didn't work. Try again.", @response.parsed_body["message"]
    end
  end

  private
    def assertion_params(challenge:, sign_count: 1)
      origin = "http://www.example.com"

      client_data_json = {
        challenge: challenge,
        origin: origin,
        type: "webauthn.get"
      }.to_json

      authenticator_data = build_authenticator_data(sign_count: sign_count)
      signature = sign(authenticator_data, client_data_json)

      {
        credential_id: @credential.credential_id,
        response: {
          client_data_json: client_data_json,
          authenticator_data: Base64.urlsafe_encode64(authenticator_data, padding: false),
          signature: Base64.urlsafe_encode64(signature, padding: false)
        }
      }
    end

    def build_authenticator_data(sign_count:)
      rp_id_hash = Digest::SHA256.digest("www.example.com")
      flags = 0x01 | 0x04 # user present + user verified

      bytes = []
      bytes.concat(rp_id_hash.bytes)
      bytes << flags
      bytes.concat([ sign_count ].pack("N").bytes)
      bytes.pack("C*")
    end

    def sign(authenticator_data, client_data_json)
      client_data_hash = Digest::SHA256.digest(client_data_json)
      signed_data = authenticator_data + client_data_hash
      @private_key.sign("SHA256", signed_data)
    end
end
