module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  def change_email_address_using_token(token)
    return false if identity&.email_locked?

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
    return false if identity&.email_locked?

    token = generate_email_address_change_token(
      to: new_email_address,
      expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION
    )

    UserMailer.email_change_confirmation(
      email_address: new_email_address,
      token: token,
      user: self
    ).deliver_later
  end

  def change_email_address(new_email_address)
    return false if identity&.email_locked?

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
