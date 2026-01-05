class Oauth::BaseController < ApplicationController
  disallow_account_scope

  private
    def oauth_error(error, description = nil, status: :bad_request)
      render json: { error: error, error_description: description }.compact, status: status
    end

    def oauth_rate_limit_exceeded
      oauth_error "slow_down", "Too many requests", status: :too_many_requests
    end
end
