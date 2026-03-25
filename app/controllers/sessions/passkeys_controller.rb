class Sessions::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  def create
    if credential = ActionPack::Passkey.authenticate(passkey_authentication_params)
      start_new_session_for credential.holder

      respond_to do |format|
        format.html { redirect_to after_authentication_url }
        format.json { render json: { session_token: session_token } }
      end
    else
      respond_to do |format|
        format.html { redirect_to new_session_path, alert: "That passkey didn't work. Try again." }
        format.json { render json: { message: "That passkey didn't work. Try again." }, status: :unauthorized }
      end
    end
  end

  private
    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end
end
