class SessionsController < ApplicationController
  require_untenanted_access
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  def create
    magic_link = Identity.find_by_email_address(email_address)&.send_magic_link

    flash[:magic_link_code] = magic_link&.code if Rails.env.development?

    redirect_to session_magic_link_path
  end

  def destroy
    terminate_session
    redirect_to_logout_url
  end

  private
    def email_address
      params.expect(:email_address)
    end
end
