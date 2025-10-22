module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  def send_email_address_change_confirmation(new_email_address)
    token = generate_email_address_change_token(to: new_email_address, expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION)
    UserMailer.email_change_confirmation(user: self, email_address: new_email_address, token: token).deliver_later
  end

  def generate_email_address_change_token(from: email_address, to:, **options)
    options = options.reverse_merge(
      for: EMAIL_CHANGE_TOKEN_PURPOSE,
      old_email_address: from,
      new_email_address: to
    )

    to_sgid(**options).to_s
  end

  def change_email_address_using_token(token)
    parsed_token = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)

    if parsed_token.nil?
      raise ArgumentError, "The token is invalid"
    elsif parsed_token.find != self
      raise ArgumentError, "The token is for another user"
    elsif email_address != parsed_token.params.fetch("old_email_address")
      raise ArgumentError, "The token was generated for a different email address"
    else
      change_email_address(parsed_token.params.fetch("new_email_address"))
    end
  end

  private
    def change_email_address(new_email_address)
      old_email_address = email_address
      update!(email_address: new_email_address)

      begin
        IdentityProvider.change_email_address(from: old_email_address, to: new_email_address, tenant: tenant)
      rescue => e
        update!(email_address: old_email_address)
        raise e
      end
    end
end
