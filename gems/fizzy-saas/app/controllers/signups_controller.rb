class SignupsController < ApplicationController
  include Restricted

  require_untenanted_access
  require_unauthenticated_access

  layout "public"

  rate_limit only: :create, name: "short-term", to: 5,  within: 3.minutes,
             with: -> { redirect_to saas.new_signup_path, alert: "Try again later." }
  rate_limit only: :create, name: "long-term",  to: 10, within: 30.minutes,
             with: -> { redirect_to saas.new_signup_path, alert: "Try again later." }

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.create_identity
      session[:return_to_after_authenticating] = saas.new_signup_membership_path(signup: { new_user: @signup.new_user? })
      redirect_to session_magic_link_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def signup_params
      params.expect(signup: %i[ email_address ])
    end
end
