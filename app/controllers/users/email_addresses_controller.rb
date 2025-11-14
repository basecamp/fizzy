class Users::EmailAddressesController < ApplicationController
  before_action :set_user
  rate_limit to: 5, within: 1.hour, only: :create

  def new
  end

  def create
    identity = Identity.find_by_email_address(new_email_address)

    if identity&.users&.exists?(account: @user.account)
      flash[:alert] = "You already have a user in this account with that email address"
      redirect_to new_user_email_address_path(@user)
    else
      @user.send_email_address_change_confirmation(new_email_address)
    end
  end

  private
    def set_user
      @user = Current.identity.users.find(params[:user_id])
    end

    def new_email_address
      params.expect :email_address
    end
end
