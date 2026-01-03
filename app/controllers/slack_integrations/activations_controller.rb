class SlackIntegrations::ActivationsController < ApplicationController
  include BoardScoped

  before_action :ensure_admin

  def create
    @integration = @board.slack_integrations.find(params[:slack_integration_id])

    if @integration.active?
      @integration.deactivate
    else
      @integration.activate
    end

    redirect_to [ @board, @integration ]
  end
end
