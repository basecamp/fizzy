class SlackIntegrationsController < ApplicationController
  include BoardScoped

  before_action :ensure_admin
  before_action :set_integration, except: %i[index new create]

  def index
    @integrations = @board.slack_integrations.order(created_at: :desc)
  end

  def show
  end

  def new
    @integration = @board.slack_integrations.new
  end

  def create
    @integration = @board.slack_integrations.new(integration_params)
    if @integration.save
      redirect_to [ @board, @integration ]
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    Rails.logger.info "=" * 80
    Rails.logger.info "Updating Slack Integration ##{@integration.id}"
    Rails.logger.info "Received params: #{params.inspect}"
    Rails.logger.info "Integration params: #{integration_params.inspect}"
    Rails.logger.info "emoji_action_mappings param: #{integration_params[:emoji_action_mappings].inspect}"
    Rails.logger.info "emoji_action_mappings class: #{integration_params[:emoji_action_mappings].class}"
    Rails.logger.info "=" * 80

    @integration.update!(integration_params)

    Rails.logger.info "After update, emoji_action_mappings: #{@integration.emoji_action_mappings.inspect}"
    Rails.logger.info "Saved value in DB: #{@integration.read_attribute(:emoji_action_mappings).inspect}"
    Rails.logger.info "=" * 80

    respond_to do |format|
      format.html { redirect_to board_slack_integrations_path(@board) }
      format.turbo_stream
    end
  end

  def destroy
    @integration.destroy!
    redirect_to board_slack_integrations_path(@board)
  end

  private
    def set_integration
      @integration = @board.slack_integrations.find(params[:id])
    end

    def integration_params
      params.expect(slack_integration: [
        :channel_id,
        :channel_name,
        :workspace_domain,
        :webhook_secret,
        :bot_user_id,
        :bot_oauth_token,
        :sync_messages,
        :sync_thread_replies,
        :sync_reactions,
        :color,
        :emoji_action_mappings
      ])
    end
end
