class Signups::PasskeysController < ApplicationController
  include WebauthnRelyingParty

  disallow_account_scope
  allow_unauthenticated_access only: :create

  def create
    signup = Signup.new(email_address: email_param)

    if signup.valid?(:identity_creation)
      webauthn_credential = webauthn_relying_party.verify_registration(
        credential_params,
        session.delete(:webauthn_challenge)
      )

      identity = Identity.find_or_create_by!(email_address: email_param)

      identity.passkeys.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        name: passkey_name
      )

      start_new_session_for identity
      redirect_to new_signup_completion_path
    else
      redirect_to new_signup_path, alert: "Please enter a valid email address."
    end
  rescue WebAuthn::Error, JSON::ParserError, KeyError, NoMethodError => e
    Rails.logger.error "Passkey registration failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to new_signup_path, alert: "Could not register passkey. Please try again."
  end

  private
    def email_param
      params[:email_address]
    end

    def credential_params
      JSON.parse(params.require(:credential))
    end

    def passkey_name
      params[:name].presence || PlatformAgent.new(request.user_agent).os || "Passkey"
    end
end
