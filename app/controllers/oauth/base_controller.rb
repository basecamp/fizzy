class Oauth::BaseController < ApplicationController
  disallow_account_scope

  # Every authorization server response, errors, consent and sign-in
  # redirects included, is uncacheable and sends no Referer, so a code, a
  # token, a secret or an authorization request's parameters reach neither a
  # shared cache nor the page a browser goes to next. Prepended, so it runs
  # ahead of every callback that can halt, the app's authentication included:
  # a halted chain skips after_actions (RFC 6749 §5.1, §5.2).
  prepend_before_action :prevent_caching, :prevent_referrer

  # OAuth parameters are top-level names. Rails' JSON parameter wrapping would
  # also copy a JSON body under the controller's name, and for the token
  # endpoint that's `token`, an OAuth parameter of its own.
  wrap_parameters false

  # OAuth parameters that name one value (RFC 6749 §3.1: "Request and
  # response parameters MUST NOT be included more than once"). Rails turns a
  # name[]= form field or a JSON array or object into an Array or a nested
  # Parameters, and handed to a lookup such as find_by(client_id: ...), an
  # Array becomes an SQL IN list. Each endpoint refuses that shape right after
  # its availability gate, so a dark server still answers 404, and before it
  # reads anything. The authorization endpoint refuses client_id and
  # redirect_uri that early, and the rest once its redirect target is known. client_secret isn't here: Oauth::ClientAuthentication reads
  # it as a credential, and one that isn't a string fails authentication
  # (invalid_client) like any wrong secret.
  SINGLE_VALUED_PARAMETERS = %w[
    client_id redirect_uri scope state
    code code_verifier code_challenge code_challenge_method response_type
    grant_type refresh_token token token_type_hint
    resource subject_token subject_token_type requested_token_type audience account_id
  ].freeze

  private
    def require_single_valued_parameters
      if (malformed = malformed_parameter_names).any?
        refuse_malformed_parameters malformed
      end
    end

    # A JSON null is left to each endpoint, which treats it as absent or, for a
    # refresh's scope, as naming no scope.
    def malformed_parameter_names
      (SINGLE_VALUED_PARAMETERS - list_valued_parameter_names).select do |name|
        params.key?(name) && !params[name].nil? && !params[name].is_a?(String)
      end
    end

    # Parameters an endpoint takes as a list, exempt from the check above.
    def list_valued_parameter_names
      []
    end

    def refuse_malformed_parameters(names)
      oauth_error "invalid_request", malformed_parameters_description(names)
    end

    def malformed_parameters_description(names)
      "#{names.to_sentence} must #{names.one? ? "be" : "each be"} a single string"
    end

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

    def oauth_error(error, description = nil, status: :bad_request)
      render json: { error: error, error_description: description }.compact, status: status
    end

    def oauth_rate_limit_exceeded
      oauth_error "slow_down", "Too many requests", status: :too_many_requests
    end
end
