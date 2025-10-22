module IdentityProvider::LocalBackend
  extend self

  def link(email_address:, to:)
    Identity.link(email_address: email_address, to: to)
  end

  def unlink(email_address:, from:)
    Identity.unlink(email_address: email_address, from: from)
  end

  def change_email_address(from:, to:, tenant:)
    Membership.change_email_address(from: from, to: to, tenant: tenant)
  end

  def send_magic_link(email_address)
    magic_link = Identity.find_by(email_address: email_address)&.send_magic_link
    magic_link&.code
  end

  def consume_magic_link(code)
    identity = MagicLink.consume(code)
    wrap_identity(identity)
  end

  def token_for(email_address)
    identity = Identity.find_by(email_address: email_address)
    wrap_identity(identity)
  end

  def resolve_token(token)
    Identity.find_signed(token&.dig("id"))&.email_address
  end

  def verify_token(token)
    identity = Identity.find_signed(token&.dig("id"))
    wrap_identity(identity)
  end

  def tenants_for(token)
    Identity.find_signed(token&.dig("id")).memberships.pluck(:tenant, :account_name).map do |id, name|
      IdentityProvider::Tenant.new(id: id, name: name)
    end
  end

  private
    def wrap_identity(identity)
      if identity
        IdentityProvider::Token.new(identity.signed_id, identity.updated_at)
      else
        nil
      end
    end
end
