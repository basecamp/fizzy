class Users::EmailAddresses::ConfirmationsController < ApplicationController
  before_action :set_user

  def show
  end

  def create
    @user.change_email_address_using_token(token)
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end

    def token
      params.expect :email_address_token
    end
end
