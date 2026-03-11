require "test_helper"

class Account::DataTransfer::ActiveStorage::BlobKeyTraversalTest < ActionDispatch::IntegrationTest
  test "import with path traversal blob key does not leak local files" do
    blob_id = ActiveRecord::Type::Uuid.generate
    traversal_key = "../../config/deploy.yml"
    zip = build_zip_with_blob(id: blob_id, key: traversal_key)
    Account::DataTransfer::ActiveStorage::BlobRecordSet.new(Current.account).import(from: zip)
    blob = ActiveStorage::Blob.find(blob_id)

    assert_not_equal traversal_key, blob.key

    sign_in_as identities(:david)
    get rails_blob_path(blob, disposition: "inline")

    assert_response :redirect

    follow_redirect!

    assert_response :not_found
  end

  private
    def build_zip_with_blob(id:, key:)
      tempfile = Tempfile.new([ "malicious", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      writer.add_file("data/active_storage_blobs/#{id}.json", {
        id: id,
        account_id: ActiveRecord::Type::Uuid.generate,
        byte_size: 32,
        checksum: "",
        content_type: "text/plain",
        created_at: Time.current.iso8601,
        filename: "traversal.txt",
        key: key,
        metadata: {}
      }.to_json)
      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end
end
