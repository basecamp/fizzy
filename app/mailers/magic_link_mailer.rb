class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = @magic_link.identity

    mail to: @identity.email_address, subject: I18n.t("mailers.magic_link.sign_in_instructions_subject", code: @magic_link.code)
  end
end
