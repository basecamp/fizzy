# = Action Pack WebAuthn Assertion Response
#
# Handles the authenticator response from a WebAuthn authentication ceremony.
# When a user authenticates with an existing credential, the authenticator
# returns an assertion response containing a signature that proves possession
# of the private key.
#
# == Usage
#
#   # Look up the credential by ID
#   credential = user.credentials.find_by!(
#     credentail_id: params[:id]
#   )
#
#   response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
#     client_data_json: params[:response][:clientDataJSON],
#     authenticator_data: params[:response][:authenticatorData],
#     signature: params[:response][:signature],
#     credential: credential.to_public_key_credential
#   )
#
#   response.validate!(
#     challenge: session[:authentication_challenge],
#     origin: "https://example.com"
#   )
#
# == Validation
#
# In addition to the base Response validations, this class verifies:
#
# * The client data type is "webauthn.get"
# * The signature is valid for the credential's public key
#
class ActionPack::WebAuthn::Authenticator::AssertionResponse < ActionPack::WebAuthn::Authenticator::Response
  attr_reader :credential, :authenticator_data, :signature

  def initialize(credential:, authenticator_data:, signature:, **attributes)
    super(**attributes)
    @credential = credential
    @signature = signature
    @authenticator_data = ActionPack::WebAuthn::Authenticator::Data.wrap(authenticator_data)
  end

  def validate!(**args)
    super(**args)

    unless client_data["type"] == "webauthn.get"
      raise InvalidResponseError, "Client data type is not webauthn.get"
    end

    unless valid_signature?
      raise InvalidResponseError, "Invalid signature"
    end

    unless sign_count_increased?
      raise InvalidResponseError, "Sign count did not increase"
    end
  end

  private
    def valid_signature?
      client_data_hash = Digest::SHA256.digest(client_data_json)
      signed_data = authenticator_data.bytes.pack("C*") + client_data_hash

      credential.public_key.verify("SHA256", signature, signed_data)
    rescue OpenSSL::PKey::PKeyError
      false
    end

    def sign_count_increased?
      if authenticator_data.sign_count.zero? && credential.sign_count.zero?
        # Some authenticators always return 0 for the sign count, even after multiple authentications.
        # In that case, we have to check that both the stored and returned sign counts are 0,
        # which indicates that the authenticator is likely not updating the sign count.
        true
      else
        authenticator_data.sign_count > credential.sign_count
      end
    end
end
