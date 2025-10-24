class IdentityMailer < ApplicationMailer
  def email_change_confirmation(identity:, email_address:, token:, tenant:)
    @identity = identity
    @token = token
    @tenant = tenant

    mail to: email_address, subject: "Confirm your new email address"
  end
end
