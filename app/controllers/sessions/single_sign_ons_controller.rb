class Sessions::SingleSignOnsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access
  before_action :ensure_single_sign_on_configured
  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  layout "public"

  def new
  end

  def create
    authorization_request = SingleSignOn::AuthorizationRequest.start(return_to: return_to)
    url = authorization_request.url(redirect_uri: single_sign_on_redirect_uri)

    remember_single_sign_on_authorization_request authorization_request
    redirect_to url, allow_other_host: true
  rescue SingleSignOn::Error => error
    single_sign_on_failed "Fizzy cannot connect to #{SingleSignOn.provider_name}. Try again later.",
      error: error
  end

  private
    def return_to
      url_from(params[:return_to]) || session.delete(:return_to_after_authenticating)
    end
end
