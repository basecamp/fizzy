class Sessions::PasskeysController < ApplicationController
  include WebauthnRelyingParty

  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def create
    webauthn_credential = WebAuthn::Credential.from_get(credential_params, relying_party: webauthn_relying_party)
    passkey = Passkey.find_by!(external_id: webauthn_credential.id)

    webauthn_credential.verify(
      session.delete(:webauthn_challenge),
      public_key: passkey.public_key,
      sign_count: passkey.sign_count
    )

    passkey.update!(sign_count: webauthn_credential.sign_count)
    start_new_session_for passkey.identity
    redirect_to after_authentication_url
  rescue WebAuthn::Error, ActiveRecord::RecordNotFound, JSON::ParserError, KeyError, NoMethodError
    redirect_to new_session_path, alert: "Authentication failed. Try again or use email."
  end

  private
    def credential_params
      JSON.parse(params.require(:credential))
    end
end
