class Sessions::MagicLinksController < ApplicationController
  require_untenanted_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Try again in 15 minutes." }

  def show
  end

  def create
    identity_token = IdentityProvider.consume_magic_link(code)

    if identity_token.blank?
      redirect_to session_magic_link_path, alert: "Try another code."
    else
      set_current_identity(identity_token)
      redirect_to after_identification_url
    end
  end

  private
    def code
      params.expect(:code)
    end
end
