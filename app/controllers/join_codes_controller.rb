class JoinCodesController < ApplicationController
  require_untenanted_access
  allow_unauthenticated_access
  before_action :set_join_code
  before_action :ensure_join_code_is_valid

  def new
    @account_name = ApplicationRecord.with_tenant(tenant) { Account.sole.name }
  end

  def create
    Identity.transaction do
      identity = Identity.find_or_create_by!(email_address: params.expect(:email_address))
      identity.memberships.find_or_create_by!(tenant: tenant) do |membership|
        membership.join_code = code
      end
      identity.send_magic_link
    end

    session[:return_to_after_authenticating] = landing_url(script_name: "/#{tenant}")
    redirect_to session_magic_link_path
  end

  private
    def ensure_join_code_is_valid
      head :not_found unless @join_code&.active?
    end

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
