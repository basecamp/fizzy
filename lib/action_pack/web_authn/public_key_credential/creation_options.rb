# = Action Pack WebAuthn Public Key Credential Creation Options
#
# Generates options for the WebAuthn registration ceremony (creating a new
# credential). These options are passed to +navigator.credentials.create()+ in
# the browser to prompt the user to register an authenticator.
#
# == Usage
#
#   options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
#     id: current_user.id,
#     name: current_user.email,
#     display_name: current_user.name
#   )
#
#   # In your controller, return as JSON for the JavaScript WebAuthn API
#   render json: { publicKey: options.as_json }
#
# == Attributes
#
# [+id+]
#   A unique identifier for the user account. Will be Base64URL-encoded in the
#   output. This should be an opaque identifier (like a primary key), not
#   personally identifiable information.
#
# [+name+]
#   A human-readable identifier for the user account, typically an email
#   address or username. Displayed by the authenticator.
#
# [+display_name+]
#   A human-friendly name for the user, typically their full name. Displayed
#   by the authenticator during registration.
#
# [+relying_party+]
#   The relying party (your application) configuration. Defaults to
#   +ActionPack::WebAuthn.relying_party+.
#
# == Supported Algorithms
#
# By default, supports ES256 (ECDSA with P-256 and SHA-256) and RS256
# (RSASSA-PKCS1-v1_5 with SHA-256), which cover the vast majority of
# authenticators.
class ActionPack::WebAuthn::PublicKeyCredential::CreationOptions < ActionPack::WebAuthn::PublicKeyCredential::Options
  ES256 = { type: "public-key", alg: -7 }.freeze
  RS256 = { type: "public-key", alg: -257 }.freeze

  attr_reader :id, :name, :display_name, :relying_party

  # Creates a new set of credential creation options.
  #
  # ==== Options
  #
  # [+:id+]
  #   Required. The user's unique identifier.
  #
  # [+:name+]
  #   Required. The user's account name (e.g., email).
  #
  # [+:display_name+]
  #   Required. The user's display name.
  #
  # [+:relying_party+]
  #   Optional. The relying party configuration.
  def initialize(id:, name:, display_name:, **attrs)
    super(**attrs)

    @id = id
    @name = name
    @display_name = display_name
    @relying_party = relying_party
  end

  # Returns a Hash suitable for JSON serialization and passing to the
  # WebAuthn JavaScript API.
  def as_json(*)
    {
      challenge: challenge,
      rp: relying_party.as_json,
      user: {
        id: Base64.urlsafe_encode64(id.to_s, padding: false),
        name: name,
        displayName: display_name
      },
      pubKeyCredParams: [
        ES256,
        RS256
      ],
      authenticatorSelection: {
        userVerification: user_verification.to_s
      }
    }
  end
end
