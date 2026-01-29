require "test_helper"

class Account::ExportTest < ActiveSupport::TestCase
  test "build_later enqueues ExportDataJob" do
    export = Account::Export.create!(account: Current.account, user: users(:david))

    assert_enqueued_with(job: ExportDataJob, args: [ export ]) do
      export.build_later
    end
  end

  test "build sets status to failed on error" do
    export = Account::Export.create!(account: Current.account, user: users(:david))
    export.stubs(:generate_zip).raises(StandardError.new("Test error"))

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
      Zip::File.open(file.path) do |zip|
        assert zip.find_entry("storage/#{blob.key}"), "Expected blob file in zip"
      end
    end
  end
end
