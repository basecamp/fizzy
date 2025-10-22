module IdentityProvider::RemoteBackend
  extend self
  include Fizzy::Saas::Engine.routes.url_helpers

  delegate :consume_magic_link, :token_for, :resolve_token, :verify_token, :tenants_for, to: IdentityProvider::LocalBackend

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  def url_options
    default_url_options.merge(script_name: nil)
  end

  def link(email_address:, to:)
    response = InternalApiClient.new(link_identity_url).post({ email_address: email_address, to: to })

    unless response.success?
      raise IdentityProvider::Error, "Failed to link identity: #{response.error || response.code}"
    end
  end

  def unlink(email_address:, from:)
    response = InternalApiClient.new(unlink_identity_url).post({ email_address: email_address, from: from })

    unless response.success?
      raise IdentityProvider::Error, "Failed to unlink identity: #{response.error || response.code}"
    end
  end

  def change_email_address(from:, to:, tenant:)
    response = InternalApiClient.new(change_identity_email_address_url).post({ from: from, to: to, tenant: tenant })

    unless response.success?
      raise IdentityProvider::Error, "Failed to change email address: #{response.error || response.code}"
    end
  end

  def send_magic_link(email_address)
    response = InternalApiClient.new(send_magic_link_url).post({ email_address: email_address })

    if response.success?
      response.parsed_body["code"]
    else
      raise IdentityProvider::Error, "Failed to send magic link: #{response.error || response.code}"
    end
  end
end
