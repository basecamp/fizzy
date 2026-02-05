class Account::DataTransfer::ActiveStorageBlobRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(
      account: account,
      model: ActiveStorage::Blob,
      attributes: ActiveStorage::Blob.column_names - %w[service_name]
    )
  end

  private
    def import_batch(files)
      batch_data = files.map do |file|
        data = load(file)
        data.slice(*attributes).merge(
          "account_id" => account.id,
          "service_name" => ActiveStorage::Blob.service.name
        )
      end

      model.insert_all!(batch_data)
    end
end
