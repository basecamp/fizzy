module Authentication
  extend ActiveSupport::Concern

  included do
    # Checking for tenant must happen first so we redirect before trying to access the db.
    before_action :require_tenant
    prepend_before_action :clear_old_scoped_session_cookies

    before_action :require_authentication
    helper_method :authenticated?

    etag { Current.session.id if authenticated? }

    include LoginHelper
  end

  class_methods do
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
    end

    def require_untenanted_access(**options)
      skip_before_action :require_tenant, **options
      before_action :redirect_tenanted_request, **options
    end
  end

  private
    def authenticated?
      Current.session.present?
    end

    def require_tenant
      unless ApplicationRecord.current_tenant.present?
        redirect_to session_menu_url(script_name: nil)
      end
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    def clear_old_scoped_session_cookies
      if request.script_name.present? && cookies.signed[:session_token].present? && !find_session_by_cookie
        cookies.signed[:session_token] = { value: "invalid-session-token", path: request.script_name, expires: 1.hour.ago }
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def request_authentication
      if ApplicationRecord.current_tenant.present?
        session[:return_to_after_authenticating] = request.url
      end

      redirect_to_login_url
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def redirect_authenticated_user
      redirect_to root_url if authenticated?
    end

    def redirect_tenanted_request
      redirect_to root_url if ApplicationRecord.current_tenant
    end

    def start_new_session_for(identity)
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def set_current_session(session)
      logger.struct "  Authorized Identity##{session.identity.id}", authentication: { identity: { id: session.identity.id } }
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_token)
    end
end
