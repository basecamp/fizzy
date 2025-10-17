class SignupsController < ApplicationController
  require_untenanted_access

  rate_limit only: :create, name: "short-term", to: 5,  within: 3.minutes,
             with: -> { redirect_to saas.new_signup_path, alert: "Try again later." }
  rate_limit only: :create, name: "long-term",  to: 10, within: 30.minutes,
             with: -> { redirect_to saas.new_signup_path, alert: "Try again later." }

  http_basic_authenticate_with \
    name: Rails.env.test? ? "testname" : Rails.application.credentials.account_signup_http_basic_auth.name,
    password: Rails.env.test? ? "testpassword" : Rails.application.credentials.account_signup_http_basic_auth.password

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.create_identity
      session[:return_to_after_identification] = saas.new_signup_completion_path
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
