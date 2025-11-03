class Memberships::EmailAddressesController < ApplicationController
  require_untenanted_access

  before_action :set_membership
  rate_limit to: 5, within: 1.hour, only: :create

  def new
  end

  def create
    @membership.send_email_address_change_confirmation(new_email_address)
  end

  private
    def set_membership
      @membership = Current.identity.memberships.find(params[:membership_id])
    end

    def new_email_address
      params.expect :email_address
    end
end
