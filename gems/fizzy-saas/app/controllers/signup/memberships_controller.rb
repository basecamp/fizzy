class Signup::MembershipsController < ApplicationController
  require_untenanted_access

  layout "public"

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.create_membership
      redirect_to saas.new_signup_completion_path(
        signup: {
          membership_id: @signup.membership_id,
          full_name: @signup.full_name,
          account_name: @signup.account_name
        }
      )
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def signup_params
      params.expect(signup: %i[ full_name ]).with_defaults(identity: Current.identity)
    end
end
