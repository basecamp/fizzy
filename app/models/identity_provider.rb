module IdentityProvider
  Tenant = Data.define(:id, :name)

  extend self

  def self.backend
    if Bootstrap.oss_config?
      raise NotImplementedError, "No identity provider configured in OSS version"
    else
      IdentityProvider::Saas
    end
  end

  delegate :link, :unlink, :send_magic_link, :consume_magic_link, :tenants_for, :token_for, :resolve_token, :verify_token, to: :backend

  def tenants_for(identity_token)
    backend.tenants_for(identity_token)
  end
end
