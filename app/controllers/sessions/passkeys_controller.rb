class Sessions::PasskeysController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  def create
    credential = Identity::Credential.authenticate(
      passkey: passkey_params,
      challenge: session.delete(:webauthn_challenge)
    )

    if credential
      authentication_succeeded(credential.identity)
    else
      authentication_failed
    end
  end

  private
    def passkey_params
      params.expect(passkey: [ :id, :client_data_json, :authenticator_data, :signature ])
    end

    def authentication_succeeded(identity)
      start_new_session_for identity

      respond_to do |format|
        format.html { redirect_to after_authentication_url }
        format.json { render json: { session_token: session_token } }
      end
    end

    def authentication_failed
      alert_message = "That passkey didn't work. Try again."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: alert_message }
        format.json { render json: { message: alert_message }, status: :unauthorized }
      end
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end
end
