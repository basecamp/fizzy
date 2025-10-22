class Sessions::StartsController < ApplicationController
  allow_unauthenticated_access
  require_identified_access

  def new
  end

  def create
    email_address = IdentityProvider.resolve_token(resume_identity)
    user = User.find_by(email_address: email_address)

    if user
      start_new_session_for(user)
      redirect_to after_authentication_url
    else
      IdentityProvider.unlink(email_address: email_address, from: ApplicationRecord.current_tenant)
      redirect_to session_login_menu_path, alert: "You can't access this account"
    end
  end
end
