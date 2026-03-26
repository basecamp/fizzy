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
