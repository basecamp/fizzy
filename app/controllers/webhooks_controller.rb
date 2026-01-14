class WebhooksController < ApplicationController
  include BoardScoped

  before_action :ensure_admin
  before_action :set_webhook, except: %i[ index new create ]

  def index
    set_page_and_extract_portion_from @board.webhooks.ordered
  end

  def show
  end

  def new
    @webhook = @board.webhooks.new
  end

  def create
    @webhook = @board.webhooks.create!(webhook_params)
    respond_to do |format|
      format.html { redirect_to @webhook }
      format.json
    end
  end

  def edit
  end

  def update
    @webhook.update!(webhook_params.except(:url))
    respond_to do |format|
      format.html { redirect_to @webhook }
      format.json { head :no_content }
    end
  end

  def destroy
    @webhook.destroy!
    respond_to do |format|
      format.html { redirect_to board_webhooks_path }
      format.json { head :no_content }
    end
  end

  private
    def set_webhook
      @webhook = @board.webhooks.find(params[:id])
    end

    def webhook_params
      params
        .expect(webhook: [ :name, :url, subscribed_actions: [] ])
        .merge(board_id: @board.id)
    end
end
