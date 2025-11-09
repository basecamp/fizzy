class SessionsController < ApplicationController
  # FIXME: Remove this before launch!
  SIGNUP_USERNAME = Rails.env.local? ? "testname" : Rails.application.credentials.account_signup_http_basic_auth.name
  SIGNUP_PASSWORD = Rails.env.local? ? "testpassword" : Rails.application.credentials.account_signup_http_basic_auth.password
  http_basic_authenticate_with name: SIGNUP_USERNAME, password: SIGNUP_PASSWORD, realm: "Fizzy Signup", only: :create, unless: -> { Identity.exists?(email_address: email_address) }

  require_untenanted_access
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  def create
    if identity = Identity.find_by_email_address(email_address)
      magic_link = identity.send_magic_link
      flash[:magic_link_code] = magic_link&.code if Rails.env.development?
      redirect_to session_magic_link_path
    elsif signups_allowed?
      Signup.new(email_address: email_address).create_identity
      session[:return_to_after_authenticating] = saas.new_signup_membership_path
      redirect_to session_magic_link_path
    end
  end

  def destroy
    terminate_session
    redirect_to_logout_url
  end

  private
    def email_address
      params.expect(:email_address)
    end
end
