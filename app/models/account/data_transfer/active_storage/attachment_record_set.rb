class Account::DataTransfer::ActiveStorage::AttachmentRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(account: account, model: ::ActiveStorage::Attachment)
  end

  private
    def records
      ::ActiveStorage::Attachment.where(account: account)
        .where.not(record_type: INTERNAL_RECORD_TYPES)
    end
end
