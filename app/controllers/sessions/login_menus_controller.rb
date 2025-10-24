class Sessions::LoginMenusController < ApplicationController
  require_untenanted_access

  layout "public"

  def show
    @memberships = Current.identity.memberships
  end
end
