class Memberships::EmailAddressesController < ApplicationController
  disallow_account_scope

  layout "public"

  before_action :set_membership
  rate_limit to: 5, within: 1.hour, only: :create

  def new
  end

  def create
    identity = Identity.find_by_email_address(new_email_address)

    if identity&.memberships&.exists?(tenant: @membership.tenant)
      flash[:alert] = "You already have a user in this account with that email address"
      redirect_to new_email_address_path
    else
      @membership.send_email_address_change_confirmation(new_email_address)
    end
  end

  private
    def set_membership
      @membership = Current.identity.memberships.find(params[:membership_id])
    end

    def new_email_address
      params.expect :email_address
    end
end
