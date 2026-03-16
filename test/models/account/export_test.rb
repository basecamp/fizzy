require "test_helper"

class Account::ExportTest < ActiveSupport::TestCase
  test "build_later enqueues DataExportJob" do
    export = Account::Export.create!(account: Current.account, user: users(:david))

    assert_enqueued_with(job: DataExportJob, args: [ export ]) do
      export.build_later
    end
  end

  test "build sets status to failed on error" do
    export = Account::Export.create!(account: Current.account, user: users(:david))
    ZipFile.stubs(:create_for).raises(StandardError.new("Test error"))

    assert_raises(StandardError) do
      export.build
    end

    assert export.failed?
  end

  test "cleanup deletes exports completed more than 24 hours ago" do
    old_export = Account::Export.create!(account: Current.account, user: users(:david), status: :completed, completed_at: 25.hours.ago)
    recent_export = Account::Export.create!(account: Current.account, user: users(:david), status: :completed, completed_at: 23.hours.ago)
    pending_export = Account::Export.create!(account: Current.account, user: users(:david), status: :pending)

    Export.cleanup

    assert_not Export.exists?(old_export.id)
    assert Export.exists?(recent_export.id)
    assert Export.exists?(pending_export.id)
  end

  test "build generates zip with account data" do
    export = Account::Export.create!(account: Current.account, user: users(:david))

    export.build

    assert export.completed?
    assert export.file.attached?
    assert_equal "application/zip", export.file.content_type
  end

  test "build includes blob files in zip" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("moon.jpg").open,
      filename: "moon.jpg",
      content_type: "image/jpeg"
    )
    export = Account::Export.create!(account: Current.account, user: users(:david))

    export.build

    assert export.completed?
    export.file.open do |file|
      reader = ZipKit::FileReader.read_zip_structure(io: file)
      entry = reader.find { |e| e.filename == "storage/#{blob.key}" }
      assert entry, "Expected blob file in zip"
    end
  end

  test "export excludes blobs and attachments from previous exports" do
    first_export = Account::Export.create!(account: Current.account, user: users(:david))
    first_export.build
    assert first_export.completed?

    first_export_blob = first_export.file.blob
    first_export_attachment = first_export.file.attachment

    second_export = Account::Export.create!(account: Current.account, user: users(:david))
    second_export.build
    assert second_export.completed?

    second_export.file.open do |file|
      reader = ZipKit::FileReader.read_zip_structure(io: file)
      filenames = reader.map(&:filename)

      blob_entries = filenames.select { |f| f.start_with?("data/active_storage_blobs/") }
      blob_ids = blob_entries.map { |f| File.basename(f, ".json") }
      assert_not_includes blob_ids, first_export_blob.id, "Export should not include blob metadata from previous exports"

      storage_entries = filenames.select { |f| f.start_with?("storage/") }
      assert_not storage_entries.any? { |f| f == "storage/#{first_export_blob.key}" },
        "Export should not include blob file from previous exports"

      attachment_entries = filenames.select { |f| f.start_with?("data/active_storage_attachments/") }
      attachment_ids = attachment_entries.map { |f| File.basename(f, ".json") }
      assert_not_includes attachment_ids, first_export_attachment.id,
        "Export should not include attachment records from previous exports"
    end
  end

  test "export keeps blobs shared with account records even when also attached to exports" do
    shared_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("shared blob content"),
      filename: "shared.txt",
      content_type: "text/plain"
    )
    card = cards(:logo)
    card.image.attach(shared_blob)
    non_internal_attachment = card.image.attachment

    prior_export = Account::Export.create!(account: Current.account, user: users(:david))
    prior_export.file.attach(shared_blob)
    internal_attachment = prior_export.file.attachment

    export = Account::Export.create!(account: Current.account, user: users(:david))
    export.build
    assert export.completed?

    export.file.open do |file|
      reader = ZipKit::FileReader.read_zip_structure(io: file)
      filenames = reader.map(&:filename)

      blob_entries = filenames.select { |f| f.start_with?("data/active_storage_blobs/") }
      blob_ids = blob_entries.map { |f| File.basename(f, ".json") }
      assert_includes blob_ids, shared_blob.id

      storage_entries = filenames.select { |f| f.start_with?("storage/") }
      assert_includes storage_entries, "storage/#{shared_blob.key}"

      attachment_entries = filenames.select { |f| f.start_with?("data/active_storage_attachments/") }
      attachment_ids = attachment_entries.map { |f| File.basename(f, ".json") }
      assert_includes attachment_ids, non_internal_attachment.id
      assert_not_includes attachment_ids, internal_attachment.id
    end
  end

  test "build succeeds when rich text references missing blob" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("moon.jpg").open,
      filename: "moon.jpg",
      content_type: "image/jpeg"
    )
    card = cards(:logo)
    card.update!(description: "<action-text-attachment sgid=\"#{blob.attachable_sgid}\"></action-text-attachment>")
    ActiveStorage::Blob.where(id: blob.id).delete_all

    export = Account::Export.create!(account: Current.account, user: users(:david))

    export.build

    assert export.completed?
  end
end
