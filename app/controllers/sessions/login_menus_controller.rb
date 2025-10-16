class Sessions::LoginMenusController < ApplicationController
  require_untenanted_access only: :show
  allow_unauthenticated_access only: :create
  skip_before_action :verify_authenticity_token, only: :create

  def show
    @tenants = IdentityProvider.tenants_for(resume_identity)
  end

  def create
    user = User.find_by(email_address: IdentityProvider.resolve_token(resume_identity))

    if user
      start_new_session_for(user)
      redirect_to after_authentication_url
    else
      IdentityProvider.unlink(email_address: IdentityProvider.resolve_token(Current.identity_token), from: ApplicationRecord.current_tenant)
      redirect_to session_login_menu_path, alert: "You can't access this account"
    end
  end
end
