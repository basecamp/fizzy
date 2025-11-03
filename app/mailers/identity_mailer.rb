class IdentityMailer < ApplicationMailer
  def email_change_confirmation(email_address:, token:, membership:)
    @token = token
    @membership = membership
    mail to: email_address, subject: "Confirm your new email address"
  end
end
