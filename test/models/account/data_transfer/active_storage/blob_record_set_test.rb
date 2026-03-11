require "test_helper"

class Account::DataTransfer::ActiveStorage::BlobRecordSetTest < ActiveSupport::TestCase
  test "import generates fresh keys instead of using exported keys" do
    blob_id = ActiveRecord::Type::Uuid.generate
    exported_key = "original-exported-key-abc123"

    zip = build_zip_with_blob(id: blob_id, key: exported_key)
    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)

    blob = ActiveStorage::Blob.find(blob_id)
    assert_not_equal exported_key, blob.key
    assert_equal 28, blob.key.length
  end

  test "import preserves blob metadata" do
    blob_id = ActiveRecord::Type::Uuid.generate

    zip = build_zip_with_blob(
      id: blob_id,
      key: "some-key",
      filename: "report.pdf",
      content_type: "application/pdf",
      byte_size: 12345,
      checksum: "abc123checksum"
    )
    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)

    blob = ActiveStorage::Blob.find(blob_id)
    assert_equal "report.pdf", blob.filename.to_s
    assert_equal "application/pdf", blob.content_type
    assert_equal 12345, blob.byte_size
    assert_equal "abc123checksum", blob.checksum
  end

  private
    def build_zip_with_blob(id:, key:, filename: "test.txt", content_type: "text/plain", byte_size: 32, checksum: "")
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/active_storage_blobs/#{id}.json", {
        id: id,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: byte_size,
        checksum: checksum,
        content_type: content_type,
        created_at: Time.current.iso8601,
        filename: filename,
        key: key,
        metadata: {}
      }.to_json)
      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end
end
