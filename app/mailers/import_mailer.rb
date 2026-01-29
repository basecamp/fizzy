class ImportMailer < ApplicationMailer
  def completed(identity)
    mail to: identity.email_address, subject: "Your Fizzy account import is complete"
  end

  def failed(identity)
    mail to: identity.email_address, subject: "Your Fizzy account import failed"
  end
end
