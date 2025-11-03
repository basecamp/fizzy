class UserMailer < ApplicationMailer
  def email_change_confirmation(user:, email_address:, token:)
    @user = user
    @token = token

    mail to: email_address, subject: "Confirm your new email address"
  end
end
