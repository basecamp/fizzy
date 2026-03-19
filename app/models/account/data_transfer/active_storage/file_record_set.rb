class Account::DataTransfer::ActiveStorage::FileRecordSet < Account::DataTransfer::RecordSet
  def initialize(account)
    super(account: account, model: ::ActiveStorage::Blob)
  end

  private
    def records
      ::ActiveStorage::Blob.where(account: account).where.not(id: excluded_blob_ids)
    end

    def excluded_blob_ids
      ::ActiveStorage::Attachment.where(account: account, record_type: INTERNAL_RECORD_TYPES).select(:blob_id)
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
        old_key = file.delete_prefix("storage/")
        blob_id = old_key_to_blob_id[old_key]
        raise IntegrityError, "Storage file #{old_key} has no matching blob metadata in export" unless blob_id
        next if internal_blob_ids.include?(blob_id)

        blob = ::ActiveStorage::Blob.find_by(id: blob_id, account: account)
        raise IntegrityError, "Blob #{blob_id} not found for storage key #{old_key}" unless blob

        zip.read(file) do |stream|
          blob.upload(stream)
        end
      end
    end

    def old_key_to_blob_id
      @old_key_to_blob_id ||= build_old_key_to_blob_id
    end

    def build_old_key_to_blob_id
      zip.glob("data/active_storage_blobs/*.json").each_with_object({}) do |file, map|
        data = load(file)
        old_key = data["key"]
        if map.key?(old_key)
          raise IntegrityError, "Duplicate blob key in export: #{old_key}"
        end
        map[old_key] = data["id"]
      end
    end

    def check_record(file_path)
      old_key = file_path.delete_prefix("storage/")
      blob_id = old_key_to_blob_id[old_key]

      unless blob_id
        raise IntegrityError, "Storage file #{old_key} has no matching blob metadata in export"
      end
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
      @old_key_to_blob_id = nil
      super
    end
end
