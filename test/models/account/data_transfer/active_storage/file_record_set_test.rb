require "test_helper"

class Account::DataTransfer::ActiveStorage::FileRecordSetTest < ActiveSupport::TestCase
  test "import uploads file data to blobs with regenerated keys" do
    blob_id = ActiveRecord::Type::Uuid.generate
    old_key = "original-key-for-file"
    file_content = "hello world file content"

    zip = build_zip_with_blob_and_file(blob_id: blob_id, old_key: old_key, file_content: file_content)

    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)
    Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).import(from: zip)

    blob = ActiveStorage::Blob.find(blob_id)
    assert_not_equal old_key, blob.key
    assert_equal file_content, blob.download
  end

  test "import handles keys containing path separators" do
    blob_id = ActiveRecord::Type::Uuid.generate
    old_key = "folder/subfolder/file-key"
    file_content = "nested key content"

    zip = build_zip_with_blob_and_file(blob_id: blob_id, old_key: old_key, file_content: file_content)

    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)
    Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).import(from: zip)

    blob = ActiveStorage::Blob.find(blob_id)
    assert_not_equal old_key, blob.key
    assert_equal file_content, blob.download
  end

  test "import raises IntegrityError for storage file without matching blob metadata" do
    blob_id = ActiveRecord::Type::Uuid.generate
    old_key = "key-with-metadata"
    orphan_key = "orphaned-storage-key"

    zip = build_zip_with_orphaned_storage_file(
      blob_id: blob_id,
      old_key: old_key,
      orphan_key: orphan_key
    )

    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)

    assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).import(from: zip)
    end
  end

  test "import raises IntegrityError when mapped blob is not found in database" do
    blob_id = ActiveRecord::Type::Uuid.generate
    old_key = "key-for-missing-blob"

    zip = build_zip_with_blob_and_file(blob_id: blob_id, old_key: old_key, file_content: "data")

    # Import file data WITHOUT importing blob metadata first
    assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).import(from: zip)
    end
  end

  test "check raises IntegrityError for storage file without matching blob metadata" do
    blob_id = ActiveRecord::Type::Uuid.generate
    old_key = "key-with-metadata"
    orphan_key = "orphaned-storage-key"

    zip = build_zip_with_orphaned_storage_file(
      blob_id: blob_id,
      old_key: old_key,
      orphan_key: orphan_key
    )

    assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).check(from: zip)
    end
  end

  test "check skips storage files for internal record type blobs" do
    internal_blob_id = ActiveRecord::Type::Uuid.generate
    normal_blob_id = ActiveRecord::Type::Uuid.generate

    zip = build_zip_with_internal_and_normal_blobs(
      internal_blob_id: internal_blob_id,
      internal_key: "internal-variant-key",
      normal_blob_id: normal_blob_id,
      normal_key: "normal-photo-key"
    )

    # check should not raise for the internal blob's storage file
    assert_nothing_raised do
      Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).check(from: zip)
    end
  end

  test "import skips uploading storage files for internal record type blobs" do
    internal_blob_id = ActiveRecord::Type::Uuid.generate
    normal_blob_id = ActiveRecord::Type::Uuid.generate
    normal_content = "normal file content"

    zip = build_zip_with_internal_and_normal_blobs(
      internal_blob_id: internal_blob_id,
      internal_key: "internal-variant-key",
      normal_blob_id: normal_blob_id,
      normal_key: "normal-photo-key",
      normal_file_content: normal_content
    )

    # Import only the normal blob (internal one should be skipped by BlobRecordSet too)
    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)

    assert_not ActiveStorage::Blob.exists?(id: internal_blob_id),
      "Internal blob should not have been imported"
    assert ActiveStorage::Blob.exists?(id: normal_blob_id),
      "Normal blob should have been imported"

    Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).import(from: zip)

    blob = ActiveStorage::Blob.find(normal_blob_id)
    assert_equal normal_content, blob.download
  end

  test "import raises IntegrityError for duplicate blob keys in export" do
    blob_id_1 = ActiveRecord::Type::Uuid.generate
    blob_id_2 = ActiveRecord::Type::Uuid.generate
    duplicate_key = "same-key-for-both"

    zip = build_zip_with_duplicate_keys(
      blob_id_1: blob_id_1,
      blob_id_2: blob_id_2,
      key: duplicate_key
    )

    assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      Account::DataTransfer::ActiveStorage::FileRecordSet.new(Current.account).import(from: zip)
    end
  end

  private
    def build_zip_with_blob_and_file(blob_id:, old_key:, file_content:)
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/active_storage_blobs/#{blob_id}.json", {
        id: blob_id,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: file_content.bytesize,
        checksum: Digest::MD5.base64digest(file_content),
        content_type: "text/plain",
        created_at: Time.current.iso8601,
        filename: "test.txt",
        key: old_key,
        metadata: {}
      }.to_json)
      writer.add_file("storage/#{old_key}", file_content, compress: false)
      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end

    def build_zip_with_orphaned_storage_file(blob_id:, old_key:, orphan_key:)
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/active_storage_blobs/#{blob_id}.json", {
        id: blob_id,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: 10,
        checksum: "",
        content_type: "text/plain",
        created_at: Time.current.iso8601,
        filename: "test.txt",
        key: old_key,
        metadata: {}
      }.to_json)
      writer.add_file("storage/#{old_key}", "file data", compress: false)
      writer.add_file("storage/#{orphan_key}", "orphan data", compress: false)
      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end

    def build_zip_with_internal_and_normal_blobs(internal_blob_id:, internal_key:, normal_blob_id:, normal_key:, normal_file_content: "normal data")
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)

      # Blob metadata JSONs
      writer.add_file("data/active_storage_blobs/#{internal_blob_id}.json", {
        id: internal_blob_id,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: 10,
        checksum: "",
        content_type: "image/jpeg",
        created_at: Time.current.iso8601,
        filename: "variant.jpg",
        key: internal_key,
        metadata: {}
      }.to_json)

      writer.add_file("data/active_storage_blobs/#{normal_blob_id}.json", {
        id: normal_blob_id,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: normal_file_content.bytesize,
        checksum: Digest::MD5.base64digest(normal_file_content),
        content_type: "image/jpeg",
        created_at: Time.current.iso8601,
        filename: "photo.jpg",
        key: normal_key,
        metadata: {}
      }.to_json)

      # Attachment metadata JSONs
      internal_attachment_id = ActiveRecord::Type::Uuid.generate
      writer.add_file("data/active_storage_attachments/#{internal_attachment_id}.json", {
        id: internal_attachment_id,
        account_id: ActiveRecord::Type::Uuid.generate,
        blob_id: internal_blob_id,
        record_type: "ActiveStorage::VariantRecord",
        record_id: ActiveRecord::Type::Uuid.generate,
        name: "file",
        created_at: Time.current.iso8601
      }.to_json)

      normal_attachment_id = ActiveRecord::Type::Uuid.generate
      writer.add_file("data/active_storage_attachments/#{normal_attachment_id}.json", {
        id: normal_attachment_id,
        account_id: ActiveRecord::Type::Uuid.generate,
        blob_id: normal_blob_id,
        record_type: "Card",
        record_id: ActiveRecord::Type::Uuid.generate,
        name: "file",
        created_at: Time.current.iso8601
      }.to_json)

      # Storage files
      writer.add_file("storage/#{internal_key}", "internal data", compress: false)
      writer.add_file("storage/#{normal_key}", normal_file_content, compress: false)

      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end

    def build_zip_with_duplicate_keys(blob_id_1:, blob_id_2:, key:)
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/active_storage_blobs/#{blob_id_1}.json", {
        id: blob_id_1,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: 10,
        checksum: "",
        content_type: "text/plain",
        created_at: Time.current.iso8601,
        filename: "file1.txt",
        key: key,
        metadata: {}
      }.to_json)
      writer.add_file("data/active_storage_blobs/#{blob_id_2}.json", {
        id: blob_id_2,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: 10,
        checksum: "",
        content_type: "text/plain",
        created_at: Time.current.iso8601,
        filename: "file2.txt",
        key: key,
        metadata: {}
      }.to_json)
      writer.add_file("storage/#{key}", "file data", compress: false)
      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end
end
