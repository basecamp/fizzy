class Users::EmailAddresses::ConfirmationsController < ApplicationController
  before_action :set_user
  rate_limit to: 3, within: 1.hour, only: :create

  def show
  end

  def create
    @user.change_email_address_using_token(token)
    redirect_to edit_user_path(@user)
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end

    def token
      params.expect :email_address_token
    end
end
