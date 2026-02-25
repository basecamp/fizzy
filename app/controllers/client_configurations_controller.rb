class ClientConfigurationsController < ApplicationController
  skip_before_action :require_account, :require_authentication
  allow_unauthorized_access

  def show
    expires_in 1.minute, public: true

    render action: client_configuration_name
  end

  private
    def client_configuration_name
      "#{params.require(:platform)}_v#{params.require(:version)}"
    end
end
