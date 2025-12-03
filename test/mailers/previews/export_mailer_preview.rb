class ExportMailerPreview < ActionMailer::Preview
  def completed
    export = Account::Export.new(
      id: "preview-export-id",
      account: Account.first,
      user: User.first
    )

    ExportMailer.completed(export)
  end
end
