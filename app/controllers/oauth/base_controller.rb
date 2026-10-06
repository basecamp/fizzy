class Oauth::BaseController < ApplicationController
  disallow_account_scope

  private
    # The metadata issuer and the iss authorization response parameter must be
    # identical (RFC 9207 §2). script_name: nil keeps an account prefix out of it.
    def oauth_issuer
      root_url(script_name: nil)
    end

    def oauth_error(error, description = nil, status: :bad_request)
      render json: { error: error, error_description: description }.compact, status: status
    end

    def oauth_rate_limit_exceeded
      oauth_error "slow_down", "Too many requests", status: :too_many_requests
    end
end
