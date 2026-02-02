class Notifications::UnsubscribesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  before_action :set_user

  def new
  end

  def create
    @user.settings.bundle_email_never!
    redirect_to notifications_unsubscribe_path(access_token: params[:access_token])
  end

  def show
  end

  private
    def set_user
      unless @user = User.find_by_token_for(:unsubscribe, params[:access_token])
        redirect_to root_path, alert: "Invalid unsubscribe link"
      end
    end
end
