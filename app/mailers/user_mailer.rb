class UserMailer < ApplicationMailer
  def email_change_confirmation(email_address:, token:, user:)
    @token = token
    @user = user
    mail to: email_address, subject: I18n.t("mailers.user_mailer.email_change_confirmation_subject")
  end
end
