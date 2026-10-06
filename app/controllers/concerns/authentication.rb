module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_account # Checking and setting account must happen first
    before_action :require_authentication
    helper_method :authenticated?, :oauth_grant?
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

    # An OAuth grant acts for an app on the user's data. It may not manage the
    # user's credentials or consent to apps: anything it minted there would
    # outlive disconnecting the app, and anything it removed would be another
    # app's. Declared on every controller that does either: personal access
    # tokens, Connected Apps, passkeys, transfer links, email changes and OAuth
    # consent. For the same reason it may not read a credential that would
    # outlive the grant: the account join code, and account exports, which carry
    # that code and every webhook's credentials. Webhooks themselves stay
    # readable but withhold their credentials (see webhooks/_webhook.json).
    def disallow_oauth_grants(**options)
      before_action :forbid_oauth_grant, **options
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

    def oauth_grant?
      Current.access_token&.oauth_client_id?
    end

    def forbid_oauth_grant
      head :forbidden if oauth_grant?
    end

    def require_account
      unless Current.account.present?
        redirect_to main_app.session_menu_path(script_name: nil)
      end
    end

    def require_authentication
      resume_session || authenticate_by_bearer_token || request_authentication
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
      if bearer_authorization?
        if bearer_token_authenticatable_request?
          authenticate_with_bearer_token
        else
          request_bearer_authentication error: "invalid_request", error_description: "Bearer tokens authenticate JSON requests only"
        end
      end
    end

    # The auth-scheme is a case-insensitive token (RFC 9110 §11.1), read with the
    # same pattern Rails parses the header with.
    def bearer_authorization?
      request.authorization.to_s[ActionController::HttpAuthentication::Token::AUTH_SCHEME_REGEX, 1].to_s.casecmp?("Bearer")
    end

    # A token that is unknown, expired, revoked or not honored is invalid_token,
    # which tells an OAuth client to refresh. A good token without the permission
    # the method needs is insufficient_scope: refreshing can't widen a grant, so
    # the client must ask for write instead (RFC 6750 §3.1).
    def authenticate_with_bearer_token
      access_token = authenticate_with_http_token(scheme: "Bearer") { |token| Identity::AccessToken.find_honored(token) }

      if access_token&.allows?(request.method)
        Current.access_token = access_token
        Current.identity = access_token.identity
      elsif access_token
        request_bearer_authentication status: :forbidden, error: "insufficient_scope",
          error_description: "The access token is read-only", scope: "write"
      else
        request_bearer_authentication error: "invalid_token", error_description: "The access token is expired, revoked, or invalid"
      end
    end

    def bearer_token_authenticatable_request?
      request.format.json?
    end

    def request_authentication
      if bearer_challengeable_request?
        request_bearer_authentication
      else
        if Current.account.present?
          session[:return_to_after_authenticating] = request.url
        end

        redirect_to_login_url
      end
    end

    # API clients that sent no credentials get a challenge rather than a sign-in
    # page (RFC 6750 §3). Our own pages keep the redirect: they send a session
    # cookie, stale or not, or ask over XHR, and @rails/request.js navigates to a
    # 401's WWW-Authenticate value as if it were a URL.
    def bearer_challengeable_request?
      request.format.json? && !request.xhr? && cookies[:session_token].blank?
    end

    def request_bearer_authentication(status: :unauthorized, **params)
      headers["WWW-Authenticate"] = bearer_challenge(**params)
      head status
    end

    def bearer_challenge(**params)
      params = { realm: "Application", resource_metadata: protected_resource_metadata_url, **params }.compact
      "Bearer " + params.map { |name, value| %(#{name}="#{value}") }.join(", ")
    end

    # RFC 9728 §5.1. Discovery 404s while OAuth is dark, so the challenge names it
    # only while it answers.
    def protected_resource_metadata_url
      if Oauth::Availability.acceptance_enabled?
        "#{main_app.root_url(script_name: nil)}.well-known/oauth-protected-resource"
      end
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
      Current.identity&.close_remote_connections(reconnect: true)
      cookies.delete(:session_token)
    end

    def session_token
      cookies[:session_token]
    end
end
