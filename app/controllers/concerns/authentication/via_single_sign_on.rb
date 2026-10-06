module Authentication::ViaSingleSignOn
  AUTHORIZATION_REQUEST_LIMIT = 3

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
    if group = SingleSignOn.admin_group
      "Only members of the #{SingleSignOn.provider_name} group #{group} can create accounts."
    else
      "This server does not allow new accounts."
    end
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

  # Requests are keyed by `state`, so several tabs can sign in at the same time.
  def remember_single_sign_on_authorization_request(authorization_request)
    requests = single_sign_on_authorization_requests
    requests[authorization_request.state] = authorization_request.to_session

    session[:single_sign_on_authorization_requests] = requests.to_a.last(AUTHORIZATION_REQUEST_LIMIT).to_h
  end

  def consume_single_sign_on_authorization_request(state)
    requests = single_sign_on_authorization_requests

    if (attributes = requests.delete(state.to_s))
      session[:single_sign_on_authorization_requests] = requests
      SingleSignOn::AuthorizationRequest.from_session(attributes)
    end
  end

  def single_sign_on_authorization_requests
    session[:single_sign_on_authorization_requests].to_h.dup
  end

  # A new session keeps an older session from gaining single sign-on access.
  def start_single_sign_on_session_for(identity, groups: [])
    terminate_session if Current.session
    start_new_session_for identity, single_sign_on_authenticated_at: Time.current, single_sign_on_groups: groups
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

  def single_sign_on_failed(message, error: nil)
    Rails.error.report(error, handled: true, severity: :warning) if error

    @single_sign_on_failure_message = message
    render "sessions/single_sign_ons/failure", status: :unauthorized
  end
end
