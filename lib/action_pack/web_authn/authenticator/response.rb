# = Action Pack WebAuthn Authenticator Response
#
# Abstract base class for WebAuthn authenticator responses. Provides common
# validation logic for both registration (attestation) and authentication
# (assertion) ceremonies.
#
# This class should not be instantiated directly. Use AttestationResponse for
# registration or AssertionResponse for authentication.
#
# == Validation
#
# The +validate!+ method performs security checks required by the WebAuthn
# specification:
#
# * Challenge verification - ensures the response matches the server-generated challenge
# * Origin verification - ensures the response comes from the expected origin
# * User verification - optionally requires biometric or PIN verification
#
# == Example
#
#   response.validate!(
#     challenge: session[:webauthn_challenge],
#     origin: "https://example.com",
#     user_verification: :required
#   )
#
class ActionPack::WebAuthn::Authenticator::Response
  # Raised when response validation fails.
  class InvalidResponseError < StandardError; end

  attr_reader :client_data_json

  def initialize(client_data_json:)
    @client_data_json = client_data_json
  end

  def valid?(**args)
    validate!(**args)
    true
  rescue InvalidResponseError
    false
  end

  def validate!(challenge:, origin:, user_verification: :preferred)
    unless challenge_matches?(challenge)
      raise InvalidResponseError, "Challenge does not match"
    end

    unless origin_matches?(origin)
      raise InvalidResponseError, "Origin does not match"
    end

    unless relying_party_id_matches?(origin)
      raise InvalidResponseError, "Relying party ID does not match origin"
    end

    unless user_present?
      raise InvalidResponseError, "User presence is required"
    end

    if user_verification == :required && !user_verified?
      raise InvalidResponseError, "User verification is required"
    end
  end

  def client_data
    @client_data ||= JSON.parse(client_data_json)
  end

  def authenticator_data
    nil
  end

  private
    def challenge_matches?(expected_challenge)
      ActiveSupport::SecurityUtils.secure_compare(expected_challenge, client_data["challenge"])
    end

    def origin_matches?(expected_origin)
      ActiveSupport::SecurityUtils.secure_compare(expected_origin, client_data["origin"])
    end

    def relying_party_id_matches?(origin)
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.digest(URI.parse(origin).host),
        authenticator_data&.relying_party_id_hash || ""
      )
    end

    def user_present?
      authenticator_data&.user_present?
    end

    def user_verified?
      authenticator_data&.user_verified?
    end
end
