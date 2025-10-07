class Sessions::MagicLinksController < ApplicationController
  require_unauthenticated_access
  skip_before_action :require_tenant

  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Try again in 15 minutes." }

  def show
  end

  def create
    @memberships = MagicLink.consume(code)&.identity&.memberships

    if @memberships.blank?
      redirect_to session_magic_link_path, alert: "Try another code."
    end
  end

  private
    def code
      params.expect(:code)
    end
end
