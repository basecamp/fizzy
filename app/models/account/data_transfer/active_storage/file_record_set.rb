class Account::DataTransfer::ActiveStorage::FileRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(account: account, model: ::ActiveStorage::Blob)
  end

  private
    def records
      ::ActiveStorage::Blob.where(account: account)
    end

    def export_record(blob)
      if blob.service.exist?(blob.key)
        zip.add_file("storage/#{blob.key}", compress: false) do |out|
          blob.download { |chunk| out.write(chunk) }
        end
      end
    end

    def files
      zip.glob("storage/*")
    end

    def import_batch(files)
      files.each do |file|
        key = File.basename(file)
        blob = ::ActiveStorage::Blob.find_by(key: key, account: account)
        next unless blob

        zip.read(file) do |stream|
          blob.upload(stream)
        end
      end
    end

    def check_record(file_path)
      key = File.basename(file_path)

      unless zip.exists?("data/active_storage_blobs/#{key}.json") || ::ActiveStorage::Blob.exists?(key: key, account: account)
        # File exists without corresponding blob record - could be orphaned or blob not yet imported
        # We allow this since blob metadata is imported before files
      end
    end
end
