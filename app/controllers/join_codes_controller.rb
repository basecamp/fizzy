class JoinCodesController < ApplicationController
  require_untenanted_access
  allow_unauthenticated_access
  before_action :set_join_code

  def new
    @account_name = ApplicationRecord.with_tenant(tenant) { Account.sole.name }
  end

  def create
    identity = Identity.find_or_create_by(email_address: params.expect(:email_address))
    identity.link_to(tenant, context: { origin: :join_code, join_code: code })
    identity.send_magic_link

    redirect_to session_magic_link_path
  end

  private
    def set_join_code
      @join_code ||= ApplicationRecord.with_tenant(tenant) { Account::JoinCode.active.find_by(code: code) }
    end

    def tenant
      params.expect(:tenant)
    end

    def code
      params.expect(:code)
    end
end
