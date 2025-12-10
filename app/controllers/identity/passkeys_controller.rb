class Identity::PasskeysController < ApplicationController
  include WebauthnRelyingParty

  disallow_account_scope

  layout "public"

  def index
    @passkeys = Current.identity.passkeys.order(created_at: :desc)
  end

  def new
    @options = passkey_registration_options
    session[:webauthn_challenge] = @options.challenge
  end

  def create
    webauthn_credential = webauthn_relying_party.verify_registration(
      credential_params,
      session.delete(:webauthn_challenge)
    )

    Current.identity.passkeys.create!(
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      name: passkey_name
    )

    redirect_to identity_passkeys_path, notice: "Passkey added successfully."
  rescue WebAuthn::Error, JSON::ParserError, KeyError, NoMethodError
    redirect_to new_identity_passkey_path, alert: "Could not register passkey."
  end

  def destroy
    passkey = Current.identity.passkeys.find(params[:id])
    passkey.destroy
    redirect_to identity_passkeys_path, notice: "Passkey removed."
  end

  private
    def passkey_registration_options
      webauthn_relying_party.options_for_registration(
        user: {
          id: encode_webauthn_user_id(Current.identity.id),
          name: Current.identity.email_address,
          display_name: Current.identity.email_address
        },
        authenticator_selection: {
          resident_key: "required",
          user_verification: "required"
        },
        exclude: Current.identity.passkeys.pluck(:external_id)
      )
    end

    def credential_params
      JSON.parse(params.require(:credential))
    end

    def passkey_name
      params[:name].presence || PlatformAgent.new(request.user_agent).os || "Passkey"
    end
end
