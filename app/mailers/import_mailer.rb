class ImportMailer < ApplicationMailer
  def completed(identity, account)
    @account = account
    mail to: identity.email_address, subject: I18n.t("mailers.import.completed_subject")
  end

  def failed(identity)
    mail to: identity.email_address, subject: I18n.t("mailers.import.failed_subject")
  end
end
