class Sessions::LoginMenusController < ApplicationController
  require_untenanted_access

  def show
    @tenants = IdentityProvider.tenants_for(resume_identity)
  end
end
