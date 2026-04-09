class Users::EmailAddressesController < ApplicationController
  before_action :set_user
  before_action :ensure_valid_email_address, only: :create
  rate_limit to: 5, within: 1.hour, only: :create

  def new
  end

  def create
    @user.send_email_address_change_confirmation(new_email_address)

    respond_to do |format|
      format.html
      format.json { head :created }
    end
  end

  private
    def set_user
      @user = Current.identity.users.find(params[:user_id])
    end

    def ensure_valid_email_address
      if !new_email_address.match?(URI::MailTo::EMAIL_REGEXP)
        error = "Please enter a valid email address"
      elsif (identity = Identity.find_by_email_address(new_email_address))
        if identity == @user.identity
          error = "That is already your email address"
        elsif identity.users.exists?(account: @user.account)
          error = "You already have a user in this account with that email address"
        end
      end

      if error
        respond_to do |format|
          format.html { redirect_to new_user_email_address_path(@user), alert: error }
          format.json { render json: { error: error }, status: :unprocessable_entity }
        end
      end
    end

    def new_email_address
      params.expect :email_address
    end
end
