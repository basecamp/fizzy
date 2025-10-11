class Sessions::LoginMenusController < ApplicationController
  require_untenanted_access only: :show
  allow_unauthenticated_access only: :create
  before_action :require_identity
  before_action :set_identity

  def show
    @memberships = @identity.memberships
  end

  def create
    membership = @identity.memberships.find(membership_id)
    start_new_session_for(membership.user)
    redirect_to after_authentication_url
  end

  private
    def set_identity
      @identity = Current.identity_token.identity
    end

    def membership_id
      params.expect :membership_id
    end
end
