class Sessions::ChoicesController < ApplicationController
  include WebauthnRelyingParty

  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
    @identity = Identity.find_by_email_address(email_address)

    if @identity.nil? || @identity.passkeys.none?
      redirect_to new_session_path
      return
    end

    @passkey_options = passkey_authentication_options
    session[:webauthn_challenge] = @passkey_options.challenge
  end

  def create
    if params[:method] == "magic_link"
      send_magic_link
    else
      authenticate_with_passkey
    end
  end

  private
    def email_address
      params[:email]
    end

    def passkey_authentication_options
      webauthn_relying_party.options_for_authentication(
        user_verification: "required"
      )
    end

    def send_magic_link
      identity = Identity.find_by_email_address!(email_address)
      redirect_to_session_magic_link identity.send_magic_link
    end

    def authenticate_with_passkey
      identity = Identity.find_by_email_address!(email_address)
      webauthn_credential = WebAuthn::Credential.from_get(credential_params, relying_party: webauthn_relying_party)
      passkey = identity.passkeys.find_by!(external_id: webauthn_credential.id)

      webauthn_credential.verify(
        session.delete(:webauthn_challenge),
        public_key: passkey.public_key,
        sign_count: passkey.sign_count
      )

      passkey.update!(sign_count: webauthn_credential.sign_count)
      start_new_session_for identity
      redirect_to after_authentication_url
    rescue WebAuthn::Error, ActiveRecord::RecordNotFound, JSON::ParserError, KeyError, NoMethodError
      redirect_to new_session_choice_path(email: email_address), alert: "Authentication failed. Try again."
    end

    def credential_params
      JSON.parse(params.require(:credential))
    end
end
