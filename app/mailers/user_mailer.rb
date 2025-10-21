class UserMailer < ApplicationMailer
  def email_change_confirmation(email_address:, token:)
    @token = token

    mail to: email_address, subject: "Confirm your new email address"
  end
end
