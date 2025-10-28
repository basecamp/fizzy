class Signups::MembershipsController < ApplicationController
  include Restricted

  require_untenanted_access

  layout "public"

  def new
    @signup = Signup.new(new_user: params.dig(:signup, :new_user) || false)
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.create_membership
      redirect_to saas.new_signup_completion_path(
        signup: {
          membership_id: @signup.membership_id,
          full_name: @signup.full_name,
          company_name: @signup.company_name
        }
      )
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def signup_params
      params.expect(signup: %i[ full_name company_name new_user]).with_defaults(new_user: false, identity: Current.identity)
    end
end
