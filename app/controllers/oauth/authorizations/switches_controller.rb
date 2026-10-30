# "Not you?" on the consent screen. Signs the person out, then brings whoever
# signs in next back to the same authorization request. The request is rebuilt
# from its parameters once they have passed every check the consent screen's
# did, never taken as a URL, so the only place this can return anyone to is
# consent for that request. The account choice isn't carried: it was the
# signed-out identity's, so the account check that guards granting doesn't
# apply here. The resource is carried, so an audienced request comes back as
# one, and its consent asks the new identity to pick an account.
class Oauth::Authorizations::SwitchesController < Oauth::AuthorizationsController
  AUTHORIZATION_PARAMS = %i[ client_id redirect_uri response_type scope state code_challenge code_challenge_method resource ]

  # Account eligibility belongs to the identity being signed out, so neither
  # account check applies; the request-level audience check still does.
  skip_before_action :set_account, :set_accounts
  before_action :require_browser_session


  # A request too long to keep in the session can't be resumed, so the person
  # stays signed in rather than signing out to nowhere.
  def create
    return_to = new_oauth_authorization_url(script_name: nil, **authorization_params)

    if return_to.bytesize <= RETURN_URL_MAXIMUM_LENGTH
      terminate_session
      reset_session
      session[:return_to_after_authenticating] = return_to

      redirect_to_login_url
    else
      render_error "invalid_request", "Authorization request too long to resume after switching",
        message: "This request is too long to pick up again after switching. Sign out, sign in as the right person, then connect from the app again."
    end
  end

  private
    # Switching signs a browser out. A request authenticated by a bearer token
    # has no session to end, so it is refused rather than half-handled.
    def require_browser_session
      unless Current.session
        render_error "access_denied", "Switching requires a browser session", status: :forbidden,
          message: "Switching to someone else works only in a browser where you've signed in to Fizzy."
      end
    end

    # Switching identity is a POST but authorizes nothing, so a metadata
    # document client is only read here, never registered.
    def persist_metadata_document?
      false
    end

    def authorization_params
      params.permit(*AUTHORIZATION_PARAMS).to_h.symbolize_keys
    end
end
