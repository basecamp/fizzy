class Sessions::PasskeysController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded
  before_action :set_webauthn_host

  def create
    if credential = Identity::Credential.find_by(credential_id: credential_id)
      authenticate credential
    else
      authentication_failed
    end
  end

  private
    def authenticate(credential)
      public_key_credential = credential.to_public_key_credential

      public_key_credential.authenticate(
        client_data_json: response_params[:client_data_json],
        authenticator_data: decode64(response_params[:authenticator_data]),
        signature: decode64(response_params[:signature]),
        challenge: session.delete(:webauthn_challenge),
        origin: request.base_url
      )

      credential.update!(sign_count: public_key_credential.sign_count)
      start_new_session_for credential.identity

      respond_to do |format|
        format.html { redirect_to after_authentication_url }
        format.json { render json: { session_token: session_token } }
      end
    rescue ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError => error
      Rails.logger.error "[Passkey] Authentication failed: #{error.message}"
      authentication_failed
    end

    def authentication_failed
      alert_message = "That passkey didn't work. Try again."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: alert_message }
        format.json { render json: { message: alert_message }, status: :unauthorized }
      end
    end

    def credential_id
      params.expect(:credential_id)
    end

    def response_params
      params.expect(response: [ :client_data_json, :authenticator_data, :signature ])
    end

    def set_webauthn_host
      ActionPack::WebAuthn::Current.host = request.host
    end

    def decode64(value)
      Base64.urlsafe_decode64(value)
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end
end
