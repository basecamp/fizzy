class Sessions::MagicLinksController < ApplicationController
  require_untenanted_access
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Try again in 15 minutes." }

  layout "public"

  def show
  end

  def create
    if identity = MagicLink.consume(code)
      start_new_session_for identity
      redirect_to after_authentication_url
    else
      redirect_to session_magic_link_path, alert: "Try another code."
    end
  end

  private
    def code
      params.expect(:code)
    end
end
