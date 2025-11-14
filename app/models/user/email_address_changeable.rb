module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  class_methods do
    def change_email_address_using_token(token)
      parsed_token = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)
      user = parsed_token&.find

      if parsed_token.nil?
        raise ArgumentError, "The token is invalid"
      elsif user.nil?
        raise ArgumentError, "The user no longer exists"
      elsif user.identity.email_address != parsed_token.params.fetch("old_email_address")
        raise ArgumentError, "The token was generated for a different email address"
      else
        new_email_address = parsed_token.params.fetch("new_email_address")
        user.change_email_address(new_email_address)
      end
    end
  end

  def send_email_address_change_confirmation(new_email_address)
    token = generate_email_address_change_token(
      to: new_email_address,
      expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION
    )

    IdentityMailer.email_change_confirmation(
      email_address: new_email_address,
      token: token,
      user: self
    ).deliver_later
  end

  def change_email_address(new_email_address)
    transaction do
      new_identity = Identity.find_or_create_by!(email_address: new_email_address)
      update!(identity: new_identity)
    end

    self
  end

  private
    def generate_email_address_change_token(from: identity.email_address, to:, **options)
      options = options.reverse_merge(
        for: EMAIL_CHANGE_TOKEN_PURPOSE,
        old_email_address: from,
        new_email_address: to,
      )

      to_sgid(**options).to_s
    end
end
