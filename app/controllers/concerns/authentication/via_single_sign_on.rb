module Authentication::ViaSingleSignOn
  AUTHORIZATION_REQUEST_COOKIE_PREFIX = "single_sign_on_"
  STATE_FORMAT = /\A[A-Za-z0-9_-]{1,64}\z/

  private

  def ensure_single_sign_on_configured
    head :not_found unless SingleSignOn.configured?
  end

  # A configured provider is the only way in, so access tokens and other sessions get no access.
  def require_single_sign_on_session
    if SingleSignOn.configured? && !Current.session&.recently_authenticated_by_single_sign_on?
      request_single_sign_on
    end
  end

  def ensure_sign_in_without_single_sign_on_allowed
    if SingleSignOn.configured?
      respond_to do |format|
        format.html { redirect_to main_app.new_session_url(script_name: nil), alert: single_sign_on_required_message }
        format.json do
          render status: :forbidden,
            json: { error: "single_sign_on_required", message: single_sign_on_required_message }
        end
      end
    end
  end

  def ensure_account_creation_allowed_by_single_sign_on
    unless single_sign_on_allows_account_creation?
      respond_to do |format|
        format.html { redirect_to main_app.session_menu_url(script_name: nil), alert: account_creation_refused_message }
        format.json do
          render status: :forbidden,
            json: { error: "account_creation_not_allowed", message: account_creation_refused_message }
        end
      end
    end
  end

  def single_sign_on_allows_account_creation?
    !SingleSignOn.configured? || Current.session&.single_sign_on_account_creator?
  end

  def account_creation_refused_message
    "Only members of the #{SingleSignOn.provider_name} group #{SingleSignOn.admin_group} can create accounts."
  end

  def request_single_sign_on
    respond_to do |format|
      format.html do
        session[:return_to_after_authenticating] = single_sign_on_return_url
        redirect_to main_app.new_session_single_sign_on_url(script_name: nil)
      end

      format.json do
        render status: :forbidden,
          json: { error: "single_sign_on_required", message: single_sign_on_required_message }
      end

      format.any { head :forbidden }
    end
  end

  def single_sign_on_return_url
    if request.get? && !turbo_frame_request? && request.headers["X-Sec-Purpose"] != "prefetch"
      request.url
    else
      url_from(request.referer) || main_app.landing_url
    end
  end

  def single_sign_on_required_message
    "Sign in with #{SingleSignOn.provider_name}."
  end

  def single_sign_on_redirect_uri
    main_app.session_single_sign_on_callback_url(script_name: nil)
  end

  # Each request has its own cookie, because tabs that share one session cookie overwrite each other's requests.
  def remember_single_sign_on_authorization_request(authorization_request)
    cookies.encrypted[single_sign_on_authorization_cookie(authorization_request.state)] = {
      value: authorization_request.to_h, expires: SingleSignOn::AuthorizationRequest::EXPIRATION_TIME,
      path: single_sign_on_authorization_cookie_path, httponly: true, same_site: :lax
    }
  end

  def consume_single_sign_on_authorization_request(state)
    if STATE_FORMAT.match?(state.to_s) && (attributes = cookies.encrypted[single_sign_on_authorization_cookie(state)])
      cookies.delete single_sign_on_authorization_cookie(state), path: single_sign_on_authorization_cookie_path
      SingleSignOn::AuthorizationRequest.from_h(attributes)
    end
  end

  def single_sign_on_authorization_cookie(state)
    "#{AUTHORIZATION_REQUEST_COOKIE_PREFIX}#{state}"
  end

  def single_sign_on_authorization_cookie_path
    main_app.session_single_sign_on_path(script_name: nil)
  end

  # A new session keeps an older session from gaining single sign-on access.
  def start_single_sign_on_session_for(identity, groups: [])
    terminate_session if Current.session
    start_new_session_for identity, single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SingleSignOn.issuer,
      single_sign_on_groups: groups
  end

  # A recent sign-in carries the current groups, so another sign-in cannot help and would loop.
  def refuse_single_sign_on_group
    respond_to do |format|
      format.html do
        render "sessions/single_sign_ons/group_required", layout: "public", status: :forbidden,
          locals: { return_to: single_sign_on_return_url }
      end

      format.json do
        render status: :forbidden,
          json: { error: "single_sign_on_group_required", message: single_sign_on_group_required_message }
      end

      format.any { head :forbidden }
    end
  end

  def single_sign_on_group_required_message
    "This account requires the #{SingleSignOn.provider_name} group #{Current.account.single_sign_on_group}."
  end

  def single_sign_on_failed(message, error: nil, status: :unauthorized)
    Rails.error.report(error, handled: true, severity: :warning) if error

    @single_sign_on_failure_message = message
    render "sessions/single_sign_ons/failure", status: status
  end

  def single_sign_on_rate_limited
    single_sign_on_failed "There are too many sign-in attempts from your network. Wait a minute, then try again.",
      status: :too_many_requests
  end
end
