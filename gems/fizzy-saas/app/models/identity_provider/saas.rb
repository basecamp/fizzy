module IdentityProvider::Saas
  # This is used to instantiate an Identity-like object from the `identity_token` without hitting
  # the untenanted database. It is intended to be used with caching/etagging methods.
  Mock = Struct.new(:id, :updated_at)
  class Error < StandardError; end

  extend self
  extend Fizzy::Saas::Engine.routes.url_helpers

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  def url_options
    default_url_options
  end

  def link(email_address:, to:)
    response = InternalApiClient.new(link_identity_url(script_name: nil)).post({ email_address: email_address, to: to })

    unless response.success?
      raise Error, "Failed to link identity: #{response.error || response.code}"
    end
  end

  def unlink(email_address:, from:)
    response = InternalApiClient.new(unlink_identity_url(script_name: nil)).post({ email_address: email_address, from: from })

    unless response.success?
      raise Error, "Failed to unlink identity: #{response.error || response.code}"
    end
  end

  def change_email_address(from:, to:, tenant:)
    response = InternalApiClient.new(change_identity_email_address_url(script_name: nil)).post({ from: from, to: to, tenant: tenant })

    unless response.success?
      raise Error, "Failed to change email address: #{response.error || response.code}"
    end
  end

  def send_magic_link(email_address)
    response = InternalApiClient.new(send_magic_link_url(script_name: nil)).post({ email_address: email_address })

    if response.success?
      response.parsed_body["code"]
    else
      raise Error, "Failed to send magic link: #{response.error || response.code}"
    end
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
    identity = Identity.find_signed(token&.dig("id"))
    identity&.email_address
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
        Mock.new(identity.signed_id, identity.updated_at)
      else
        nil
      end
    end
end
