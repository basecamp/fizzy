class Account::DataTransfer::ActiveStorage::AttachmentRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(account: account, model: ::ActiveStorage::Attachment)
  end

  private
    def records
      ::ActiveStorage::Attachment.where(account: account)
        .where.not(record_type: INTERNAL_RECORD_TYPES)
    end

    def check_record(file_path)
      data = load(file_path)
      return if data["record_type"].in?(INTERNAL_RECORD_TYPES)

      super
    end

    def import_batch(files)
      batch_data = files.filter_map do |file|
        data = load(file)
        next if data["record_type"].in?(INTERNAL_RECORD_TYPES)

        data.slice(*attributes).merge("account_id" => account.id).tap do |record_data|
          record_data["updated_at"] = Time.current if record_data.key?("updated_at")
        end
      end

      model.insert_all!(batch_data) if batch_data.any?
    end
end
