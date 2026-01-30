class ImportMailer < ApplicationMailer
  def completed(identity, account)
    @account = account
    mail to: identity.email_address, subject: "Your Fizzy account import is done"
  end

  def failed(identity)
    mail to: identity.email_address, subject: "Your Fizzy account import failed"
  end
end
