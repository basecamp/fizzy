class UserMailer < ApplicationMailer
  def email_change_confirmation(user:, from:, to:)
    @user = user
    @token = user.email_address_change_token(from: from, to: to)
    mail to: to, subject: "Confirm your new email address"
  end
end
