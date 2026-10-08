class Sessions::SingleSignOns::CallbacksController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access
  before_action :ensure_single_sign_on_configured
  rate_limit to: 300, within: 1.minute, only: :show, with: :single_sign_on_rate_limited

  layout "public"

  def show
    if authorization_request = consume_single_sign_on_authorization_request(params[:state])
      authenticate authorization_request
    else
      single_sign_on_failed "This sign-in request expired or is not valid. Try again."
    end
  rescue SingleSignOn::Error => error
    single_sign_on_failed "Sign-in with #{SingleSignOn.provider_name} did not work. Try again.", error: error
  end

  private
    def authenticate(authorization_request)
      claims = authorization_request.complete(params, redirect_uri: single_sign_on_redirect_uri)
      authentication = SingleSignOn::Authentication.new(claims)

      if authentication.sign_in
        start_single_sign_on_session_for authentication.identity, groups: claims.groups
        redirect_to after_single_sign_on_url(authentication, authorization_request)
      else
        single_sign_on_failed authentication.failure_message
      end
    end

    def after_single_sign_on_url(authentication, authorization_request)
      if authentication.requires_signup_completion?
        new_signup_completion_url
      else
        authorization_request.return_to.presence || after_authentication_url
      end
    end
end
