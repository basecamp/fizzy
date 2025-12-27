class Users::EmailAddresses::ConfirmationsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_user
  rate_limit to: 5, within: 1.hour, only: :create

  def show
  end

  def create
    if @user.change_email_address_using_token(token)
      terminate_session if Current.session
      start_new_session_for @user.identity

      redirect_to edit_user_url(script_name: @user.account.slug, id: @user)
    else
      render :invalid_token, status: :unprocessable_entity
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def token
      params.expect :email_address_token
    end
end
