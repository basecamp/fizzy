class Sessions::MagicLinksController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  before_action :ensure_that_email_address_pending_authentication_exists

  layout "public"

  def show
  end

  def create
    if magic_link = MagicLink.consume(code)
      respond_to_valid_code_from magic_link
    else
      respond_to_invalid_code
    end
  end

  private
    def ensure_that_email_address_pending_authentication_exists
      unless email_address_pending_authentication.present?
        alert_message = "Enter your email address to sign in."
        respond_to do |format|
          format.html { redirect_to new_session_path, alert: alert_message }
          format.json { render json: { message: alert_message }, status: :unauthorized }
        end
      end
    end

    def code
      params.expect(:code)
    end

    def respond_to_valid_code_from(magic_link)
      if email_address_pending_authentication_matches?(magic_link.identity.email_address)
        start_new_session_for magic_link.identity

        respond_to do |format|
          format.html { redirect_to after_sign_in_url(magic_link) }
          format.json { render json: { session_token: cookies[:session_token] } }
        end
      else
        alert_message = "Authentication failed. Please try again."
        respond_to do |format|
          format.html { redirect_to new_session_path, alert: alert_message }
          format.json { render json: { message: alert_message }, status: :unauthorized }
        end
      end
    end

    def respond_to_invalid_code
      respond_to do |format|
        format.html { redirect_to session_magic_link_path, flash: { shake: true } }
        format.json { render json: { message: "Try another code." }, status: :unauthorized }
      end
    end

    def after_sign_in_url(magic_link)
      if magic_link.for_sign_up?
        new_signup_completion_path
      else
        after_authentication_url
      end
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again in 15 minutes."

      respond_to do |format|
        format.html { redirect_to session_magic_link_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end
end
