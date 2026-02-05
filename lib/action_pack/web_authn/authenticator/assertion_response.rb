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
#     external_id: params[:id]
#   )
#
#   response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
#     client_data_json: params[:response][:clientDataJSON],
#     authenticator_data: params[:response][:authenticatorData],
#     signature: params[:response][:signature],
#     credential: credential
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
    @authenticator_data = authenticator_data
    @signature = signature
  end

  def validate!(**args)
    super(**args)

    unless client_data["type"] == "webauthn.get"
      raise InvalidResponseError, "Client data type is not webauthn.get"
    end

    unless valid_signature?
      raise InvalidResponseError, "Invalid signature"
    end
  end

  def user_verified?
    parsed_authenticator_data.user_verified?
  end

  private
    def parsed_authenticator_data
      @parsed_authenticator_data ||= ActionPack::WebAuthn::Authenticator::AuthenticatorData.decode(authenticator_data)
    end

    def valid_signature?
      client_data_hash = Digest::SHA256.digest(client_data_json)
      signed_data = authenticator_data + client_data_hash

      credential.public_key.verify("SHA256", signature, signed_data)
    rescue OpenSSL::PKey::PKeyError
      false
    end
end
