class Webhooks::DeliveriesController < ApplicationController
  include BoardScoped

  before_action :ensure_admin
  before_action :set_webhook

  def index
    respond_to do |format|
      format.json do
        set_page_and_extract_portion_from @webhook.deliveries.ordered.includes(event: [ :creator, { eventable: :card } ])
      end
    end
  end

  private
    def set_webhook
      @webhook = @board.webhooks.find(params[:webhook_id])
    end
end
