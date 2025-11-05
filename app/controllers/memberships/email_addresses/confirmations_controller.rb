class Memberships::EmailAddresses::ConfirmationsController < ApplicationController
  require_untenanted_access
  allow_unauthenticated_access

  before_action :set_membership
  rate_limit to: 5, within: 1.hour, only: :create

  def show
  end

  def create
    membership = Membership.change_email_address_using_token(token)

    terminate_session if Current.session
    start_new_session_for membership.reload.identity

    redirect_to edit_user_url(script_name: "/#{@membership.tenant}", id: @membership.user)
  end

  private
    def set_membership
      @membership = Membership.find(params[:membership_id])
    end

    def token
      params.expect :email_address_token
    end
end
