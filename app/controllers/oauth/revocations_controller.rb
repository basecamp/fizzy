class Oauth::RevocationsController < Oauth::BaseController
  allow_unauthenticated_access

  before_action :set_access_token

  def create
    @access_token&.destroy

    head :ok  # Don't behave as oracle, per RFC 7009
  end

  private
    def set_access_token
      @access_token = Identity::AccessToken.find_by(token: params.require(:token))
    end
end
