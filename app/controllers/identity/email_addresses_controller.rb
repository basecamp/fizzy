class Identity::EmailAddressesController < ApplicationController
  require_untenanted_access

  before_action :set_identity
  rate_limit to: 3, within: 1.hour, only: :create

  def new
    @tenant = params[:tenant]
    @user = ApplicationRecord.with_tenant(@tenant) { Current.identity.user }
  end

  def create
    @tenant = tenant
    @user = ApplicationRecord.with_tenant(@tenant) { Current.identity.user }

    if Identity.exists?(email_address: new_email_address)
      flash.now[:alert] = "Someone else already uses that email"
      render :new, status: :unprocessable_entity
    else
      @identity.send_email_address_change_confirmation(new_email_address, tenant: tenant)
    end
  end

  private
    def set_identity
      @identity = Current.identity
    end

    def new_email_address
      params.expect :email_address
    end

    def tenant
      params.expect :tenant
    end
end
