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

  test "import skips blobs referenced only by internal record type attachments" do
    internal_blob_id = ActiveRecord::Type::Uuid.generate
    normal_blob_id = ActiveRecord::Type::Uuid.generate

    zip = build_zip_with_blobs_and_attachments(
      blobs: [
        { id: internal_blob_id, key: "internal-key", filename: "variant.jpg" },
        { id: normal_blob_id, key: "normal-key", filename: "photo.jpg" }
      ],
      attachments: [
        { id: ActiveRecord::Type::Uuid.generate, blob_id: internal_blob_id, record_type: "ActiveStorage::VariantRecord" },
        { id: ActiveRecord::Type::Uuid.generate, blob_id: normal_blob_id, record_type: "Card" }
      ]
    )

    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)

    assert_not ActiveStorage::Blob.exists?(id: internal_blob_id),
      "Should not import blob for internal record type"
    assert ActiveStorage::Blob.exists?(id: normal_blob_id),
      "Should still import blob for non-internal record type"
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

    def build_zip_with_blobs_and_attachments(blobs:, attachments:)
      tempfile = Tempfile.new([ "test_export", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)

      blobs.each do |blob|
        writer.add_file("data/active_storage_blobs/#{blob[:id]}.json", {
          id: blob[:id],
          account_id: ActiveRecord::Type::Uuid.generate,
          byte_size: 32,
          checksum: "",
          content_type: "image/jpeg",
          created_at: Time.current.iso8601,
          filename: blob[:filename],
          key: blob[:key],
          metadata: {}
        }.to_json)
      end

      attachments.each do |attachment|
        writer.add_file("data/active_storage_attachments/#{attachment[:id]}.json", {
          id: attachment[:id],
          account_id: ActiveRecord::Type::Uuid.generate,
          blob_id: attachment[:blob_id],
          record_type: attachment[:record_type],
          record_id: ActiveRecord::Type::Uuid.generate,
          name: "file",
          created_at: Time.current.iso8601
        }.to_json)
      end

      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end
end
