class Sessions::LoginMenusController < ApplicationController
  require_untenanted_access
  require_identified_access

  layout "public"

  def show
    @tenants = IdentityProvider.tenants_for(resume_identity)
  end
end
