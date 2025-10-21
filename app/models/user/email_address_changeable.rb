module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"

  extend ActiveSupport::Concern

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
      update!(email_address: parsed_token.params.fetch("new_email_address"))
    end
  end
end
