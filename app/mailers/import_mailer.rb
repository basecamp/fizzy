class ImportMailer < ApplicationMailer
  def completed(identity, account)
    @account = account
    mail to: identity.email_address, subject: "Your Fizzy account import is done"
  end

  def failed(import)
    @import = import
    mail to: import.identity.email_address, subject: "Your Fizzy account import failed"
  end
end
