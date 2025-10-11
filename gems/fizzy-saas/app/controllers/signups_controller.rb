class SignupsController < ApplicationController
  require_untenanted_access

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.create_account
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
