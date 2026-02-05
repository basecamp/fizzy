# = Action Pack WebAuthn Public Key Credential Request Options
#
# Generates options for the WebAuthn authentication ceremony (using an existing
# credential). These options are passed to +navigator.credentials.get()+ in
# the browser to prompt the user to authenticate with a registered authenticator.
#
# == Usage
#
#   options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
#     credentials: current_user.webauthn_credentials
#   )
#
#   # In your controller, return as JSON for the JavaScript WebAuthn API
#   render json: { publicKey: options.as_json }
#
# == Attributes
#
# [+credentials+]
#   A collection of credential records for the user. Each credential must
#   respond to +credential_id+ returning the Base64URL-encoded credential ID.
#
# [+relying_party+]
#   The relying party (your application) configuration. Defaults to
#   +ActionPack::WebAuthn.relying_party+.
class ActionPack::WebAuthn::PublicKeyCredential::RequestOptions < ActionPack::WebAuthn::PublicKeyCredential::Options
  attr_reader :credentials

  # Creates a new set of credential request options.
  #
  # ==== Options
  #
  # [+:credentials+]
  #   Required. The user's registered WebAuthn credentials.
  #
  # [+:relying_party+]
  #   Optional. The relying party configuration.
  def initialize(credentials:, **attrs)
    super(**attrs)

    @credentials = credentials
  end

  # Returns a Hash suitable for JSON serialization and passing to the
  # WebAuthn JavaScript API.
  def as_json(*)
    {
      challenge: challenge,
      rpId: relying_party.id,
      allowCredentials: credentials.map do |credential|
        {
          type: "public-key",
          id: credential.credential_id
        }
      end,
      userVerification: user_verification.to_s
    }
  end
end
