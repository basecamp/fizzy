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
    # identical (RFC 9207 §2), and clients compare them to the issuer they were
    # configured with as exact strings (RFC 8414 §3.3). Like bc3's
    # canonical_issuer_url, it's the origin with no trailing slash:
    # https://app.fizzy.do. script_name: nil keeps an account prefix out of it.
    def oauth_issuer
      root_url(script_name: nil).delete_suffix("/")
    end

    def prevent_caching
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
    end

    def prevent_referrer
      response.headers["Referrer-Policy"] = "no-referrer"
    end

    # Every error answer is announced as error.oauth, for metrics (SaaS counts
    # them in Yabeda). The client is named by its type alone: a self-registered
    # client's id is anyone's to mint, so it can't be a metric label.
    def oauth_error(error, description = nil, status: :bad_request)
      ActiveSupport::Notifications.instrument "error.oauth",
        endpoint: controller_name, error_code: error, client_type: oauth_error_client&.client_type || "unknown"

      render_oauth_error error, description, status: status
    end

    # A throttled request is counted as a rate-limit hit and not as an error,
    # so a burst of retries doesn't read as a spike of failures.
    def oauth_rate_limit_exceeded
      ActiveSupport::Notifications.instrument "rate_limit.oauth", endpoint: controller_name
      render_oauth_error "slow_down", "Too many requests", status: :too_many_requests
    end

    def render_oauth_error(error, description, status:)
      render json: { error: error, error_description: description }.compact, status: status
    end

    # The client an error answers, if the request got as far as finding one.
    def oauth_error_client
      @client
    end
end
