module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_account # Checking and setting account must happen first
    before_action :require_authentication
    helper_method :authenticated?
    helper_method :email_address_pending_authentication

    etag { Current.identity.id if authenticated? }

    include Authentication::ViaMagicLink, LoginHelper
  end

  class_methods do
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
      allow_unauthorized_access **options
    end

    def disallow_account_scope(**options)
      skip_before_action :require_account, **options
      before_action :redirect_tenanted_request, **options
    end
  end

  private
    def authenticated?
      Current.identity.present?
    end

    def require_account
      unless Current.account.present?
        redirect_to main_app.session_menu_path(script_name: nil)
      end
    end

    def require_authentication
      # Prefer gateway identity when request has trusted Forward Auth headers so an old session does not override.
      authenticate_by_forward_auth || resume_session || authenticate_by_bearer_token || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def authenticate_by_bearer_token
      if request.authorization.to_s.include?("Bearer")
        authenticate_or_request_with_http_token do |token|
          if identity = Identity.find_by_permissable_access_token(token, method: request.method)
            Current.identity = identity
          end
        end
      end
    end

    def authenticate_by_forward_auth
      config = Rails.application.config.forward_auth
      if config.blank? || !config.is_a?(ForwardAuth::Config)
        Rails.logger.debug "[ForwardAuth] Skipped: not configured"
        return false
      end
      unless config.enabled?
        Rails.logger.debug "[ForwardAuth] Skipped: disabled"
        return false
      end
      unless config.trusted?(request)
        Rails.logger.info "[ForwardAuth] Skipped: request not trusted (remote_ip=#{request.remote_ip.inspect})"
        return false
      end

      email = request.headers["X-Auth-Email"].to_s.strip.downcase.presence
      if email.blank? || !URI::MailTo::EMAIL_REGEXP.match?(email)
        Rails.logger.info "[ForwardAuth] Skipped: missing or invalid X-Auth-Email"
        return false
      end

      identity = if config.auto_provision?
        Identity.find_or_create_by!(email_address: email)
      else
        Identity.find_by(email_address: email)
      end
      unless identity
        Rails.logger.info "[ForwardAuth] Skipped: no Identity for email (auto_provision=#{config.auto_provision?})"
        return false
      end

      if Current.account.present?
        user = identity.users.find_by(account: Current.account)
        if user.nil? && config.auto_provision?
          user = create_forward_auth_user_in_account(identity, Current.account, config)
        end
        unless user
          Rails.logger.info "[ForwardAuth] Skipped: identity has no User in current account"
          return false
        end
      end

      if config.use_email_local_part_and_lock_email? && identity.respond_to?(:email_locked=)
        identity.update_column(:email_locked, true)
      end

      Current.identity = identity
      start_new_session_for(identity) if config.create_session?
      Rails.logger.info "[ForwardAuth] Authenticated identity=#{identity.id} email=#{identity.email_address}"
      true
    end

    def create_forward_auth_user_in_account(identity, account, config)
      name = if config.use_email_local_part_and_lock_email?
        email_local_part(identity.email_address)
      else
        request.headers["X-Auth-User"].to_s.strip.presence || email_local_part(identity.email_address)
      end
      identity.users.create!(
        name: name,
        account: account,
        role: config.default_role,
        verified_at: Time.current
      )
    end

    def email_local_part(email_address)
      email_address.to_s.split("@", 2).first.presence || email_address
    end

    def request_authentication
      if Current.account.present?
        session[:return_to_after_authenticating] = request.url
      end

      redirect_to_login_url
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || landing_url
    end

    def redirect_authenticated_user
      redirect_to main_app.root_url if authenticated?
    end

    def redirect_tenanted_request
      redirect_to main_app.root_url if Current.account.present?
    end

    def start_new_session_for(identity)
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_token)
    end

    def session_token
      cookies[:session_token]
    end
end
