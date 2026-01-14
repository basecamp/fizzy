class Sessions::OidcController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  skip_forgery_protection only: :create

  layout "public"

  def create
    auth_hash = request.env["omniauth.auth"]

    if auth_hash.present?
      authenticate_with_oidc(auth_hash)
    else
      Rails.logger.debug "OIDC data not found"
      authentication_failed(message: "OIDC authentication failed.")
    end
  rescue => e
    Rails.error.report(e, severity: :error)
    authentication_failed(message: "Error during OIDC authentication.")
  end

  def failure
    error_type = params[:message] || "unknown_error"
    authentication_failed(message: "OIDC authentication failed: #{error_type}")
  end
end
