module IdentityProvider
  Tenant = Data.define(:id, :name)

  extend self

  def self.backend
    if defined?(IdentityProvider::Saas)
      IdentityProvider::Saas
    else
      IdentityProvider::Simple
    end
  end

  delegate :link, :unlink, :send_magic_link, :consume_magic_link, :tenants_for, :token_for, :resolve_token, :verify_token, to: :backend

  module Simple
    extend self

    def link(email_address:, to:)
      Identity.link(email_address: email_address, to: to)
    end

    def unlink(email_address:, from:)
      Identity.unlink(email_address: email_address, from: from)
    end

    def send_magic_link(email_address)
      magic_link = Identity.find_by(email_address: email_address)&.send_magic_link
      magic_link&.code
    end

    def consume_magic_link(code)
      MagicLink.consume(code)
    end

    def token_for(email_address)
      Identity.find_by(email_address: email_address)
    end

    def resolve_token(token)
      Identity.find_signed(token&.dig("id"))&.email_address
    end

    def verify_token(token)
      Identity.find_signed(token&.dig("id"))
    end

    def tenants_for(token)
      Identity.find_signed(token&.dig("id")).memberships.pluck(:tenant, :account_name).map do |id, name|
        IdentityProvider::Tenant.new(id: id, name: name)
      end
    end
  end
end
