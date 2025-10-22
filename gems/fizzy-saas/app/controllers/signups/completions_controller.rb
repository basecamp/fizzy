class Signups::CompletionsController < ApplicationController
  include Restricted

  require_untenanted_access
  require_identified_access

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.complete
      redirect_to new_session_start_url(script_name: "/#{@signup.tenant}")
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
