class GithubIntegrationsController < ApplicationController
  include BoardScoped

  before_action :ensure_admin
  before_action :set_integration, except: %i[index new create]

  def index
    Rails.logger.info "=== GitHub Integrations Index ==="
    Rails.logger.info "Board: #{@board.inspect}"
    Rails.logger.info "User: #{Current.user.inspect}"
    @integrations = @board.github_integrations.order(created_at: :desc)
    Rails.logger.info "Integrations count: #{@integrations.count}"
  rescue => e
    Rails.logger.error "GitHub Integrations Index Error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    raise
  end

  def show
    Rails.logger.info "=== GitHub Integration Show ==="
    Rails.logger.info "Integration: #{@integration.inspect}"
  rescue => e
    Rails.logger.error "GitHub Integration Show Error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    raise
  end

  def new
    @integration = @board.github_integrations.new
  end

  def create
    @integration = @board.github_integrations.new(integration_params)
    if @integration.save
      redirect_to [ @board, @integration ]
    else
      Rails.logger.error "GitHub Integration creation failed: #{@integration.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "GitHub Integration creation error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  def edit
  end

  def update
    @integration.update!(integration_params)
    respond_to do |format|
      format.html { redirect_to board_github_integrations_path(@board) }
      format.turbo_stream
    end
  end

  def destroy
    @integration.destroy!
    redirect_to board_github_integrations_path(@board)
  end

  private
    def set_integration
      @integration = @board.github_integrations.find(params[:id])
    end

    def integration_params
      params.expect(github_integration: [
        :repository_full_name,
        :sync_pull_requests,
        :sync_issues,
        :sync_comments,
        :sync_reviews,
        :color
      ])
    end
end
