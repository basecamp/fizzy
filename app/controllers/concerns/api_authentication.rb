module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
  end

  private
    def authenticate_api_token!
      token = extract_bearer_token
      return head :unauthorized unless token

      api_token = ApiToken.active.find_by(token: token)
      return head :unauthorized unless api_token

      # Set Current.account and Current.user from the token
      Current.account = api_token.account
      Current.user = api_token.user

      # Track token usage
      api_token.touch_last_used_at!
    rescue => e
      Rails.logger.error("[ApiAuthentication] Error: #{e.message}")
      head :unauthorized
    end

    def extract_bearer_token
      authorization_header = request.headers["Authorization"]
      return nil unless authorization_header

      match = authorization_header.match(/\ABearer\s+(.+)\z/)
      match&.captures&.first
    end
end
