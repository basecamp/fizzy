class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with:  :rate_limit_exceeded

  layout "public"

  def new
  end

  def create
    if identity = Identity.find_by_email_address(email_address)
      magic_link = identity.send_magic_link
      serve_development_magic_link(magic_link)
    end

    respond_to do |format|
      format.html do
        redirect_to session_magic_link_path
      end

      format.json do
        head :created
      end
    end
  end

  def destroy
    terminate_session
    redirect_to_logout_url
  end

  private
    def email_address
      params.expect(:email_address)
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end
end
