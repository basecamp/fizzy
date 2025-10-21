class Users::EmailAddressesController < ApplicationController
  before_action :set_user

  def new
  end

  def create
    token = user.generate_email_address_change_token(from: user.email_address, to: new_email_address, expires_in: 30.minutes)
    UserMailer.email_change_confirmation(email_address: new_email_address, token: token).delivery_later
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end

    def new_email_address
      params.expect :email_address
    end
end
