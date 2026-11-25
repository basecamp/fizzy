class UserMailer < ApplicationMailer
  def email_change_confirmation(user:, email_address:)
    @user = user
    @token = user.email_address_change_token(email_address)
    mail to: email_address, subject: "Confirm your new email address"
  end
end
