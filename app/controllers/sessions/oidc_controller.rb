class Sessions::OidcController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: ENV.fetch("OIDC_RATE_LIMIT", 10).to_i, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  skip_forgery_protection only: :create

  layout "public"

  def create
    auth_hash = request.env["omniauth.auth"]

    if auth_hash.present?
      Rails.logger.info "[OIDC] Callback for #{auth_hash.info&.email}"
      authenticate_with_oidc(auth_hash)
    else
      Rails.logger.warn "[OIDC] Data not found"
      authentication_failed(message: "OIDC authentication failed.")
    end
  rescue => e
    Rails.logger.error "[OIDC] Authentication error: #{e.class} - #{e.message}"
    Rails.error.report(e, severity: :error)
    authentication_failed(message: "Error during OIDC authentication.")
  end

  def failure
    error_type = params[:message] || "unknown_error"
    Rails.logger.warn "[OIDC] Failure: #{error_type}"
    authentication_failed(message: "OIDC authentication failed: #{error_type}")
  end
end
