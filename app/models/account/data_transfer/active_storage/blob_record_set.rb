class Account::DataTransfer::ActiveStorage::BlobRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(
      account: account,
      model: ::ActiveStorage::Blob,
      attributes: ::ActiveStorage::Blob.column_names - %w[service_name]
    )
  end

  private
    def records
      ::ActiveStorage::Blob.where(account: account).where.not(id: excluded_blob_ids)
    end

    def excluded_blob_ids
      ::ActiveStorage::Attachment.where(account: account, record_type: INTERNAL_RECORD_TYPES).select(:blob_id)
    end

    def import_batch(files)
      batch_data = files.filter_map do |file|
        data = load(file)
        next if internal_blob_ids.include?(data["id"])

        data.slice(*attributes).merge(
          "account_id" => account.id,
          "key" => ::ActiveStorage::Blob.generate_unique_secure_token(length: ::ActiveStorage::Blob::MINIMUM_TOKEN_LENGTH),
          "service_name" => ::ActiveStorage::Blob.service.name
        )
      end

      model.insert_all!(batch_data) if batch_data.any?
    end

    def internal_blob_ids
      @internal_blob_ids ||= build_internal_blob_ids
    end

    def build_internal_blob_ids
      zip.glob("data/active_storage_attachments/*.json").each_with_object(Set.new) do |file, ids|
        data = load(file)
        ids << data["blob_id"] if data["record_type"].in?(INTERNAL_RECORD_TYPES)
      end
    end

    def with_zip(zip)
      @internal_blob_ids = nil
      super
    end
end
