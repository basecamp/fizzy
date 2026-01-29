class Account::Export < Export
  private
    def populate_zip(zip)
      Account::DataTransfer::Manifest.new(account).each_record_set do |record_set|
        record_set.export(to: Account::DataTransfer::ZipFile.new(zip))
      end
    end
end
