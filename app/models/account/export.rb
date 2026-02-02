class Account::Export < Export
  private
    def filename
      "fizzy-account-#{account_id}-export-#{id}.zip"
    end

    def populate_zip(zip)
      Account::DataTransfer::Manifest.new(account).each_record_set do |record_set|
        record_set.export(to: zip)
      end
    end
end
