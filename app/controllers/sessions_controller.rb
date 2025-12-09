class SessionsController < ApplicationController
  include WebauthnRelyingParty

  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
    @passkey_options = passkey_authentication_options
    session[:webauthn_challenge] = @passkey_options.challenge
  end

  def create
    if identity = Identity.find_by_email_address(email_address)
      if identity.passkeys.any?
        redirect_to new_session_choice_path(email: email_address)
      else
        redirect_to_session_magic_link identity.send_magic_link
      end
    else
      signup = Signup.new(email_address: email_address)
      if signup.valid?(:identity_creation)
        redirect_to new_signup_path
      else
        head :unprocessable_entity
      end
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

    def passkey_authentication_options
      webauthn_relying_party.options_for_authentication(user_verification: "required")
    end
end
