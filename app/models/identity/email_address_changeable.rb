module Identity::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  def send_email_address_change_confirmation(new_email_address, tenant:)
    token = generate_email_address_change_token(to: new_email_address, tenant: tenant, expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION)
    IdentityMailer.email_change_confirmation(identity: self, email_address: new_email_address, token: token, tenant: tenant).deliver_later
  end

  def generate_email_address_change_token(from: email_address, to:, tenant:, **options)
    options = options.reverse_merge(
      for: EMAIL_CHANGE_TOKEN_PURPOSE,
      old_email_address: from,
      new_email_address: to,
      tenant: tenant
    )

    to_sgid(**options).to_s
  end

  def change_email_address_using_token(token)
    parsed_token = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)

    if parsed_token.nil?
      raise ArgumentError, "The token is invalid"
    elsif parsed_token.find != self
      raise ArgumentError, "The token is for another identity"
    elsif email_address != parsed_token.params.fetch("old_email_address")
      raise ArgumentError, "The token was generated for a different email address"
    else
      tenant = parsed_token.params.fetch("tenant")
      new_email_address = parsed_token.params.fetch("new_email_address")
      change_email_address(new_email_address, tenant: tenant)
    end
  end

  private
    def change_email_address(new_email_address, tenant:)
      old_email_address = email_address

      # First update the identity email
      update!(email_address: new_email_address)

      begin
        # Then update the membership to point to the new identity
        Membership.change_email_address(from: old_email_address, to: new_email_address, tenant: tenant)

        # Also update the user's email in the tenant database (read-only from untenanted context)
        # This will be handled by the user updating their own record
      rescue => e
        # Rollback identity email if membership update fails
        update!(email_address: old_email_address)
        raise e
      end
    end
end
