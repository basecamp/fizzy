class Memberships::UnlinkController < ApplicationController
  require_untenanted_access
  before_action :set_membership

  def show
  end

  def create
    @membership.destroy
    redirect_to session_menu_path
  end

  private
    def set_membership
      @membership = Current.identity.memberships.find_signed!(params[:membership_id], purpose: :unlinking)
    end
end
