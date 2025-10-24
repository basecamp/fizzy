class Sessions::LoginMenusController < ApplicationController
  require_untenanted_access

  layout "public"

  Tenant = Data.define(:id, :name)

  def show
    @tenants = Current.identity.memberships.map { |m| Tenant.new(id: m.tenant, name: m.account_name) }
  end
end
