class SignupsController < ApplicationController
  include WebauthnRelyingParty

  disallow_account_scope
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_signup_path, alert: "Try again later." }
  before_action :redirect_authenticated_user

  layout "public"

  def new
    @signup = Signup.new
    @passkey_options = passkey_registration_options
    session[:webauthn_challenge] = @passkey_options.challenge
  end

  def create
    signup = Signup.new(signup_params)
    if signup.valid?(:identity_creation)
      identity = Identity.find_or_create_by!(email_address: signup_params[:email_address])
      redirect_to_session_magic_link identity.send_magic_link(for: :sign_up)
    else
      head :unprocessable_entity
    end
  end

  private
    def redirect_authenticated_user
      redirect_to new_signup_completion_path if authenticated?
    end

    def signup_params
      params.expect signup: :email_address
    end

    def passkey_registration_options
      webauthn_relying_party.options_for_registration(
        user: {
          id: WebAuthn.generate_user_id,
          name: "user@example.com",
          display_name: "New User"
        },
        authenticator_selection: {
          resident_key: "required",
          user_verification: "required"
        }
      )
    end
end
