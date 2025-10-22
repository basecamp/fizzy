class Users::EmailAddressesController < ApplicationController
  before_action :set_user
  rate_limit to: 3, within: 1.hour, only: :create

  def new
  end

  def create
    if User.exists?(email_address: new_email_address)
      flash.now[:alert] = "Someone else already uses that email"
      render :new, status: :unprocessable_entity
    else
      @user.send_email_address_change_confirmation(new_email_address)
    end
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end

    def new_email_address
      params.expect :email_address
    end
end
