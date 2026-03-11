class Users::PushSubscriptionsController < ApplicationController
  wrap_parameters :push_subscription, include: %i[ endpoint p256dh_key auth_key ]

  before_action :set_push_subscriptions

  def index
  end

  def create
    subscription = @push_subscriptions.create_with(user_agent: request.user_agent).create_or_find_by!(push_subscription_params)

    respond_to do |format|
      format.html { head :no_content }
      format.json { head :created }
    end
  end

  def destroy
    @push_subscriptions.destroy_by(id: params[:id])

    respond_to do |format|
      format.html { redirect_to user_push_subscriptions_url }
      format.json { head :no_content }
    end
  end

  private
    def set_push_subscriptions
      @push_subscriptions = Current.user.push_subscriptions
    end

    def push_subscription_params
      params.require(:push_subscription).permit(:endpoint, :p256dh_key, :auth_key)
    end
end
