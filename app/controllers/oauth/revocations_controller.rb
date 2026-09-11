class Oauth::RevocationsController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  before_action :set_access_token

  def create
    @access_token&.destroy

    head :ok  # Don't behave as oracle, per RFC 7009
  end

  private
    def set_access_token
      token = params.require(:token)
      @access_token = Identity::AccessToken.find_by(token: token) ||
        Identity::AccessToken.find_by(refresh_token: token)
    end
end
