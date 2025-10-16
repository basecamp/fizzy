class SessionsController < ApplicationController
  require_untenanted_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    magic_link_code = IdentityProvider.send_magic_link(email_address)

    if magic_link_code && Rails.env.development?
      flash[:notice] = "Magic Link Code: #{magic_link_code}"
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
