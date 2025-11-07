class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = @magic_link.identity

    mail to: @identity.email_address, subject: "Your Fizzy verification code"
  end

  private
    def default_url_options
      Rails.application.config.action_mailer.default_url_options
    end
end
