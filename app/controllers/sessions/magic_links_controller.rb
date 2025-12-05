class Sessions::MagicLinksController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded

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
    def code
      params.expect(:code)
    end

    def respond_to_valid_code_from(magic_link)
      respond_to do |format|
        format.html do
          start_new_session_for magic_link.identity
          redirect_to after_sign_in_url(magic_link)
        end

        format.json do
          new_access_token = magic_link.identity.access_tokens.create!(permission: :write)
          render json: { access_token: new_access_token.token }
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
