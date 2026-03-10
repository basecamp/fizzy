class WebhooksController < ApplicationController
  wrap_parameters :webhook, include: %i[ name url subscribed_actions ]

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
    @webhook = @board.webhooks.new(webhook_params)

    if @webhook.save
      respond_to do |format|
        format.html { redirect_to @webhook }
        format.json { render :show, status: :created, location: board_webhook_url(@webhook.board, @webhook, format: :json) }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @webhook.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @webhook.update(webhook_params.except(:url))
      respond_to do |format|
        format.html { redirect_to @webhook }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @webhook.errors, status: :unprocessable_entity }
      end
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
