class Account::DataTransfer::ActiveStorage::BlobRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(
      account: account,
      model: ::ActiveStorage::Blob,
      attributes: ::ActiveStorage::Blob.column_names - %w[service_name]
    )
  end

  private
    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data.slice(*attributes).merge(
          "account_id" => account.id,
          "key" => ::ActiveStorage::Blob.generate_unique_secure_token(length: ::ActiveStorage::Blob::MINIMUM_TOKEN_LENGTH),
          "service_name" => ::ActiveStorage::Blob.service.name
        )
      end

      model.insert_all!(batch_data)
    end
end
