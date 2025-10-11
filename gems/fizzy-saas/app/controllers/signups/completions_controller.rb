class Signups::CompletionsController < ApplicationController
  allow_unauthenticated_access

  before_action :require_identity
  before_action :ensure_setup_pending
  before_action :ensure_identity_of_an_admin

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.complete
      start_new_session_for(@signup.user)
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def ensure_setup_pending
      unless Account.sole.setup_pending?
        redirect_to root_path
      end
    end

    def ensure_identity_of_an_admin
      unless user&.admin?
        redirect_to root_path
      end
    end

    def signup_params
      params.expect(signup: %i[ full_name company_name ]).with_defaults(
        tenant: ApplicationRecord.current_tenant,
        user: user
      )
    end

    def user
      @user ||= User.all.admin.with_identity(Current.identity_token.identity).first
    end
end
