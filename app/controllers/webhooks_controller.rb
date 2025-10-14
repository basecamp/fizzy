class WebhooksController < ApplicationController
  before_action :ensure_can_administer
  before_action :set_collection
  before_action :set_webhook, except: %i[ index new create ]

  def index
    set_page_and_extract_portion_from @collection.webhooks.ordered
  end

  def show
  end

  def new
    @webhook = @collection.webhooks.new
  end

  def create
    @webhook = @collection.webhooks.create!(webhook_params)
    redirect_to @webhook
  end

  def edit
  end

  def update
    @webhook.update!(webhook_params.except(:url))
    redirect_to @webhook
  end

  def destroy
    @webhook.destroy!
    redirect_to collection_webhooks_path, status: :see_other
  end

  private
    def set_collection
      @collection = Collection.find(params[:collection_id])
    end

    def set_webhook
      @webhook = @collection.webhooks.find(params[:id])
    end

    def webhook_params
      params
        .expect(webhook: [ :name, :url, subscribed_actions: [] ])
        .merge(collection_id: @collection.id)
    end
end
