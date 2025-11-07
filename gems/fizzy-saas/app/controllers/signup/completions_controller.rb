class Signup::CompletionsController < ApplicationController
  require_untenanted_access

  layout "public"

  def new
    @signup = Signup.new(signup_params)
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.complete
      redirect_to landing_url(script_name: "/#{@signup.tenant}")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def signup_params
      params.expect(signup: %i[ full_name account_name membership_id ]).with_defaults(identity: Current.identity)
    end
end
