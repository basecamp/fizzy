class Account::DataTransfer::Board::PublicationRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(account: account, model: ::Board::Publication)
  end

  private
    def check_record(file_path)
      super

      data = load(file_path)
      if !data["key"].nil? && model.exists?(key: data["key"])
        raise ConflictError, "#{model} record with key #{data['key']} already exists"
      end
    end
end
