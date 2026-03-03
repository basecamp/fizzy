require "test_helper"

class ActiveStorageAnalyzeJobSkipDetachedTest < ActiveSupport::TestCase
  test "skips analysis when blob has no attachments" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * 1024), filename: "orphan.txt", content_type: "text/plain"
    )

    blob.expects(:analyze).never

    ActiveStorage::AnalyzeJob.perform_now(blob)
  end

  test "performs analysis when blob has attachments" do
    card = cards(:logo)
    card.image.attach io: StringIO.new("x" * 1024), filename: "test.png", content_type: "image/png"
    blob = card.image.blob

    blob.expects(:analyze).once

    ActiveStorage::AnalyzeJob.perform_now(blob)
  end
end
