class GithubIntegrations::ActivationsController < ApplicationController
  before_action :ensure_admin

  def create
    integration = Current.account.github_integrations.find(params[:github_integration_id])

    if integration.active?
      integration.deactivate
    else
      integration.activate
    end

    redirect_to [ integration.board, integration ]
  end
end
