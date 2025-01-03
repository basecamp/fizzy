class FirstRunsController < ApplicationController
  allow_unauthenticated_access

  before_action :prevent_tenanted_access
  before_action :ensure_new_tenant, only: :create

  def show
  end

  def create
    ActiveRecord::Tenanted::Tenant.create(subdomain_param) do
      account = Account.create!(name: "Fizzy")
      user = account.users.create!(user_params)

      redirect_to tenanted_url(subdomain_param, session_relay_path(user.relay_id)), allow_other_host: true
    end
  end

  private
    def prevent_tenanted_access
      redirect_to root_path unless ActiveRecord::Tenanted::Tenant.untenanted?
    end

    def ensure_new_tenant
      if ActiveRecord::Tenanted::Tenant.exist?(subdomain_param)
        flash[:alert] = "Subdomain #{subdomain_param.inspect} is already taken."
        @user = User.new(user_params)

        render :show
      end
    end

    def user_params
      params.expect(user: [ :name, :email_address, :password ])
    end

    def subdomain_param
      params.expect(:subdomain)
    end

    def tenanted_url(subdomain, path)
      request.protocol +
        [ [ subdomain, request.host ].join("."), request.optional_port ].compact.join(":") +
        path
    end
end
