class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  def create
    if identity = Identity.find_by_email_address(email_address)
      magic_link = identity.send_magic_link
      serve_development_magic_link(magic_link)
    end

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
