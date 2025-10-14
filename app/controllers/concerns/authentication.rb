module Authentication
  extend ActiveSupport::Concern

  included do
    # Checking for tenant must happen first so we redirect before trying to access the db.
    before_action :require_tenant

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
      skip_before_action :require_authentication, **options
      before_action :redirect_tenanted_request, **options
    end
  end

  private
    def authenticated?
      Current.session.present?
    end

    def require_tenant
      unless ApplicationRecord.current_tenant.present?
        resume_identity
        redirect_to session_login_menu_url(script_name: nil)
      end
    end

    def require_identity
      resume_identity || request_authentication
    end

    def require_authentication
      if resume_identity
        resume_session || request_session_for_identity
      else
        request_authentication
      end
    end

    def request_session_for_identity
      redirect_to session_login_menu_url(script_name: nil)
    end

    def resume_identity
      if identity = find_identity_by_cookie
        set_current_identity(identity)
      end
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    def find_identity_by_cookie
      Identity.find_signed(cookies.signed[:identity_token]&.dig("id"))
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

    def start_new_session_for(user)
      link_identity(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def link_identity(user_or_membership)
      token_value = cookies.signed[:identity_token]
      identity = Identity.find_signed(token_value["id"]) if token_value.present?

      if user_or_membership.is_a?(User)
        identity = user_or_membership.set_identity(identity)
      elsif user_or_membership.is_a?(Membership) && identity
        user_or_membership.update!(identity: identity)
      end

      set_current_identity(identity)
    end

    def set_current_identity(identity)
      Current.identity_token = if identity
        cookies.signed.permanent[:identity_token] = { value: { "id" => identity.signed_id, "updated_at" => identity.updated_at }, httponly: true, same_site: :lax }
        Identity::Mock.new(**cookies.signed[:identity_token])
      else
        nil
      end
    end

    def set_current_session(session)
      logger.struct "  Authorized User##{session.user.id}", authentication: { user: { id: session.user.id } }
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax, path: Account.sole.slug }
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_token)
      cookies.delete(:identity_token)
    end
end
