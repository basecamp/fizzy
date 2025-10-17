class Signups::CompletionsController < ApplicationController
  require_untenanted_access
  before_action :require_identity

  http_basic_authenticate_with \
    name: Rails.env.test? ? "testname" : Rails.application.credentials.account_signup_http_basic_auth.name,
    password: Rails.env.test? ? "testpassword" : Rails.application.credentials.account_signup_http_basic_auth.password

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.complete
      redirect_to session_login_menu_path(go_to: @signup.tenant)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def signup_params
      params.expect(signup: %i[ full_name company_name ]).with_defaults(
        identity: identity,
        email_address: identity.email_address
      )
    end

    def identity
      @identity ||= Identity.find_signed(Current.identity_token.id)
    end
end
