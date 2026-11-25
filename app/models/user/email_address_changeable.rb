module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  def change_email_address_using_token(token)
    parsed_token = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)

    old_email_address = parsed_token&.params&.fetch("old_email_address")
    new_email_address = parsed_token&.params&.fetch("new_email_address")

    if parsed_token.nil? || parsed_token.find != self || identity.email_address != old_email_address
      false
    else
      change_email_address(new_email_address)
    end
  end

  def send_email_address_change_confirmation(new_email_address)
    UserMailer.email_change_confirmation(user: self, from: identity.email_address, to: new_email_address).deliver_later
  end

  def email_address_change_token(from:, to:)
    generate_email_address_change_token(from: from, to: to, expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION)
  end

  def change_email_address(new_email_address)
    transaction do
      new_identity = Identity.find_or_create_by!(email_address: new_email_address)
      update!(identity: new_identity)
    end
  end

  private
    def generate_email_address_change_token(from: identity.email_address, to:, **options)
      options = options.with_defaults(
        for: EMAIL_CHANGE_TOKEN_PURPOSE,
        old_email_address: from,
        new_email_address: to,
      )

      to_sgid(**options).to_s
    end
end
