# ActionPack::Passkey provides WebAuthn passkey registration and authentication backed by Active Record.
#
# Passkeys are scoped to a polymorphic +holder+ (typically a User or Identity) and store the
# credential ID, public key, sign count, and transport hints needed for the WebAuthn ceremonies.
#
# == Registration
#
# Generate options for the browser's +navigator.credentials.create()+ call, then register the
# response:
#
#   options = ActionPack::Passkey.registration_options(holder: current_user)
#   # Pass options to the browser
#
#   passkey = ActionPack::Passkey.register(params[:passkey], holder: current_user)
#
# == Authentication
#
# Generate options for the browser's +navigator.credentials.get()+ call, then authenticate the
# response:
#
#   options = ActionPack::Passkey.authentication_options
#   # Pass options to the browser
#
#   passkey = ActionPack::Passkey.authenticate(params[:passkey])
#
# == Holder integration
#
# Call +has_passkeys+ in your model to set up the association and configure ceremony options
# per-holder. See ActionPack::Passkey::Holder for details.
class ActionPack::Passkey < Rails.configuration.action_pack.passkey.parent_class_name.constantize
  self.table_name = "action_pack_passkeys"
  belongs_to :holder, polymorphic: true
  serialize :transports, coder: JSON, type: Array, default: []

  class << self
    # Returns a CreationOptions object for the given +holder+, suitable for passing to the
    # browser's +navigator.credentials.create()+ call. Merges global defaults from the Rails
    # configuration, holder-specific options from +holder.passkey_registration_options+, and any
    # additional +options+ overrides.
    def registration_options(holder:, **options)
      ActionPack::WebAuthn::PublicKeyCredential.creation_options(
        **Rails.configuration.action_pack.web_authn.default_creation_options.to_h,
        **holder.passkey_registration_options.to_h,
        **options
      )
    end

    # Verifies the attestation response from the browser and persists a new passkey record.
    # The +passkey+ hash should contain +client_data_json+, +attestation_object+, and +transports+
    # as submitted by the registration form. The challenge is extracted from the authenticator's
    # +clientDataJSON+ response and verified server-side. Any additional +attributes+ (e.g. +holder+)
    # are passed through to +create!+.
    #
    # Raises ActionPack::WebAuthn::InvalidResponseError if the attestation is invalid.
    def register(passkey, **attributes)
      credential = ActionPack::WebAuthn::PublicKeyCredential.register(passkey)

      create!(**credential.to_h, **attributes)
    end

    # Returns a RequestOptions object suitable for passing to the browser's
    # +navigator.credentials.get()+ call. When a +holder+ is provided, their existing credentials
    # are included so the browser can offer them for selection. Merges global defaults, holder
    # options, and any additional +options+ overrides.
    def authentication_options(holder: nil, **options)
      ActionPack::WebAuthn::PublicKeyCredential.request_options(
        **Rails.configuration.action_pack.web_authn.default_request_options.to_h,
        **holder&.passkey_authentication_options.to_h,
        **options
      )
    end

    # Looks up a passkey by credential ID and verifies the assertion response from the browser.
    # Returns the authenticated Passkey record, or +nil+ if the credential is not found or
    # verification fails.
    def authenticate(passkey)
      find_by(credential_id: passkey[:id])&.authenticate(passkey)
    end
  end

  # Verifies the assertion response against this passkey's stored credential and updates the
  # +sign_count+ and +backed_up+ attributes. Returns +self+ on success, or +nil+ if the
  # response is invalid.
  def authenticate(passkey)
    credential = to_public_key_credential
    credential.authenticate(passkey)
    update!(sign_count: credential.sign_count, backed_up: credential.backed_up)
    self
  rescue ActionPack::WebAuthn::InvalidResponseError
    nil
  end

  # Returns an ActionPack::WebAuthn::PublicKeyCredential initialized from this record's stored
  # credential data.
  def to_public_key_credential
    ActionPack::WebAuthn::PublicKeyCredential.new(
      id: credential_id,
      public_key: public_key,
      sign_count: sign_count,
      transports: transports
    )
  end
end
