class Oauth::BaseController < ApplicationController
  disallow_account_scope

  # Every authorization server response, errors, consent and sign-in
  # redirects included, is uncacheable and sends no Referer, so a code, a
  # token, a secret or an authorization request's parameters reach neither a
  # shared cache nor the page a browser goes to next. Prepended, so it runs
  # ahead of every callback that can halt, the app's authentication included:
  # a halted chain skips after_actions (RFC 6749 §5.1, §5.2).
  prepend_before_action :prevent_caching, :prevent_referrer

  private
    # Discovery follows acceptance (see Oauth::Availability): a dark server
    # answers as if it had no authorization server at all.
    def require_acceptance_enabled
      head :not_found unless Oauth::Availability.acceptance_enabled?
    end

    # Minting endpoints are 404 while dark and 503 while issuance is paused.
    # Revocation, Connected Apps and denials never call this, so people can
    # always shed access. The pilot exemption reads the claimed client_id,
    # before the client authenticates: this only decides whether the endpoint
    # answers at all.
    def require_issuance_enabled
      if !Oauth::Availability.acceptance_enabled?(piloting_client_id)
        head :not_found
      elsif !Oauth::Availability.issuance_enabled?(piloting_client_id)
        head :service_unavailable
      end
    end

    # The client a request acts for, if it names one.
    def piloting_client_id
      params[:client_id]
    end

    # The metadata issuer and the iss authorization response parameter must be
    # identical (RFC 9207 §2). script_name: nil keeps an account prefix out of it.
    def oauth_issuer
      root_url(script_name: nil)
    end

    def prevent_caching
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
    end

    def prevent_referrer
      response.headers["Referrer-Policy"] = "no-referrer"
    end

    def oauth_error(error, description = nil, status: :bad_request)
      render json: { error: error, error_description: description }.compact, status: status
    end

    def oauth_rate_limit_exceeded
      oauth_error "slow_down", "Too many requests", status: :too_many_requests
    end
end
