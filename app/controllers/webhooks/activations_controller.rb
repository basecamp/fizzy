class Webhooks::ActivationsController < ApplicationController
  include BoardScoped

  before_action :ensure_admin

  def create
    webhook = @board.webhooks.find(params[:webhook_id])
    webhook.activate

    respond_to do |format|
      format.html { redirect_to webhook }
      format.json { render partial: "webhooks/webhook", locals: { webhook: webhook }, status: :created }
    end
  end
end
