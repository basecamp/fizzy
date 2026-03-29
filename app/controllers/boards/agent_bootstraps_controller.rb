class Boards::AgentBootstrapsController < ApplicationController
  include BoardScoped

  before_action :ensure_admin
  before_action :set_agent_bootstrap, only: :show

  def new
  end

  def show
  end

  def create
    @agent_bootstrap = @board.agent_bootstraps.create!(
      account: @board.account,
      creator: Current.user,
      expires_at: expires_in_minutes.minutes.from_now,
      permission: params.fetch(:permission, :write),
      involvement: params.fetch(:involvement, :watching)
    )

    respond_to do |format|
      format.html { redirect_to board_agent_bootstrap_path(@board, @agent_bootstrap) }
      format.json { render :show, status: :created, location: board_agent_bootstrap_url(@board, @agent_bootstrap, format: :json) }
    end
  end

  private
    def set_agent_bootstrap
      @agent_bootstrap = @board.agent_bootstraps.find(params[:id])
    end

    def expires_in_minutes
      params.fetch(:expires_in_minutes, 30).to_i.clamp(5, 24.hours.in_minutes)
    end
end
