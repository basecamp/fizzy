class Webhooks::ActivationsController < ApplicationController
  before_action :ensure_admin

  def create
    webhook = Webhook.find(params[:webhook_id])
    webhook.activate

    redirect_to webhook
  end
end
