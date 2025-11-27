class SessionsController < ApplicationController
  # FIXME: Remove this before launch!
  unless Rails.env.local?
    http_basic_authenticate_with \
      name: Rails.application.credentials.account_signup_http_basic_auth.name,
      password: Rails.application.credentials.account_signup_http_basic_auth.password,
      realm: "Fizzy Signup",
      only: :create, unless: -> { Identity.exists?(email_address: email_address) }
  end

  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  def create
    if identity = Identity.find_by_email_address(email_address)
      handle_existing_user(identity)
    elsif
      handle_new_signup
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

    def handle_existing_user(identity)
      magic_link = identity.send_magic_link
      flash[:magic_link_code] = magic_link&.code if Rails.env.development?
      redirect_to session_magic_link_path
    end

    def handle_new_signup
      Signup.new(email_address: email_address).create_identity
      session[:return_to_after_authenticating] = new_signup_completion_path
      redirect_to session_magic_link_path
    end
end
