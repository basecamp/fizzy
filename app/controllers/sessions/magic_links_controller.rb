class Sessions::MagicLinksController < ApplicationController
  require_untenanted_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Try again in 15 minutes." }

  def show
  end

  def create
    membership = MagicLink.consume(code)

    if membership.blank?
      redirect_to session_magic_link_path, alert: "Try another code."
    else
      resume_identity

      if Current.identity_token
        link_identity(membership)
      else
        set_current_identity(membership.identity)
      end

      if membership.account.setup_pending?
        redirect_to saas.new_signup_completion_url(script_name: "/#{membership.user_tenant}")
      else
        redirect_to session_login_menu_path
      end
    end
  end

  private
    def code
      params.expect(:code)
    end
end
