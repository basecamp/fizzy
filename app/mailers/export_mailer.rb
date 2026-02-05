class ExportMailer < ApplicationMailer
  helper_method :export_download_url

  def completed(export)
    @export = export
    @user = export.user

    mail to: @user.identity.email_address, subject: I18n.t("mailers.export.completed_subject")
  end

  private
    def export_download_url(export)
      if export.is_a?(User::DataExport)
        user_data_export_url(export.user, export)
      else
        account_export_url(export)
      end
    end
end
