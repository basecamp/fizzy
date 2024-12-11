class FirstRunsController < ApplicationController
  allow_unauthenticated_access

  before_action :prevent_sharded_access

  def show
  end

  def create
    tenant = FirstRun.create!(tenant_params, user_params) do |user|
      start_new_session_for user
    end
    redirect_to tenanted_url(tenant, root_path), allow_other_host: true
  end

  private
    def prevent_sharded_access
      redirect_to root_path unless ApplicationRecord.current_shard == :nonexistent
    end

    def tenant_params
      params.expect(tenant: :slug)
    end

    def user_params
      params.expect(user: [ :name, :email_address, :password ])
    end

    def tenanted_url(tenant, path)
      request.protocol + [ [ tenant.slug, request.host ].join("."), request.optional_port ].compact.join(":") + path
    end
end
