require "test_helper"

class ActiveStorageTransformJobsDiscardFileNotFoundTest < ActiveSupport::TestCase
  TRANSFORMATIONS = { resize_to_limit: [ 100, 100 ] }

  setup do
    @blob = ActiveStorage::Blob.create_and_upload! \
      io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
  end

  test "transform for a blob missing from storage discards cleanly" do
    @blob.service.delete @blob.key

    Rails.error.expects(:report).with { |error, **| error.is_a?(ActiveStorage::FileNotFoundError) }

    assert_no_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::TransformJob.perform_now @blob, TRANSFORMATIONS
      end
    end
  end

  test "transform for a present blob still runs" do
    assert_difference -> { ActiveStorage::VariantRecord.count }, 1 do
      ActiveStorage::TransformJob.perform_now @blob, TRANSFORMATIONS
    end
  end

  test "create variants for a blob missing from storage discards cleanly" do
    ActiveStorage::CreateVariantsJob.any_instance.stubs(:perform).raises(ActiveStorage::FileNotFoundError)

    Rails.error.expects(:report).with { |error, **| error.is_a?(ActiveStorage::FileNotFoundError) }

    assert_nothing_raised do
      ActiveStorage::CreateVariantsJob.perform_now @blob, variants: [ TRANSFORMATIONS ], process: :immediately
    end
  end
end
