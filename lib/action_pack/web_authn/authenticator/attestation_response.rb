# = Action Pack WebAuthn Attestation Response
#
# Handles the authenticator response from a WebAuthn registration ceremony.
# When a user registers a new credential, the authenticator returns an
# attestation response containing the new public key and credential ID.
#
# == Usage
#
#   response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
#     client_data_json: params[:response][:clientDataJSON],
#     attestation_object: params[:response][:attestationObject]
#   )
#
#   response.validate!(
#     challenge: session[:registration_challenge],
#     origin: "https://example.com"
#   )
#
#   # Store the credential
#   credential_id = response.attestation.credential_id
#   public_key = response.attestation.public_key
#
# == Validation
#
# In addition to the base Response validations, this class verifies:
#
# * The client data type is "webauthn.create"
# * The attestation format has a registered verifier
# * The attestation statement passes format-specific verification
#
class ActionPack::WebAuthn::Authenticator::AttestationResponse < ActionPack::WebAuthn::Authenticator::Response
  attr_reader :attestation_object

  def initialize(attestation_object:, **attributes)
    super(**attributes)
    @attestation_object = attestation_object
  end

  def validate!(**args)
    super(**args)

    unless client_data["type"] == "webauthn.create"
      raise InvalidResponseError, "Client data type is not webauthn.create"
    end

    verifier = ActionPack::WebAuthn.attestation_verifiers[attestation.format]

    unless verifier
      raise InvalidResponseError, "Unsupported attestation format: #{attestation.format}"
    end

    verifier.verify!(attestation, client_data_json: client_data_json)
  end

  def attestation
    @attestation ||= ActionPack::WebAuthn::Authenticator::Attestation.decode(attestation_object)
  end

  def authenticator_data
    attestation.authenticator_data
  end
end
