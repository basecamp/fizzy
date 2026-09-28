require "test_helper"

class Fizzy::Saas::UnprocessableAttachmentTest < ActiveSupport::TestCase
  setup { Current.session = sessions(:david) }

  test "a comment posts when an embed's variant cannot be made" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")

    comment = nil
    assert_nothing_raised { comment = comment_with_embed }

    assert comment.persisted?
    assert_equal 1, comment.body.embeds.count
  end

  test "an avatar uploads when its variant cannot be made" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")
    user = users(:david)

    assert_nothing_raised { user.update!(avatar: Rack::Test::UploadedFile.new(file_fixture("moon.jpg"), "image/jpeg")) }

    blob = user.reload.avatar.blob
    assert blob.service.exist?(blob.key), "the original must still be uploaded"
  end

  test "the remaining variants are still attempted after one cannot be made" do
    attempted = []
    ActiveStorage::Variation.any_instance.stubs(:transform).with do |*|
      attempted << true
      true
    end.raises(Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize"))

    comment_with_embed

    assert_equal Attachments::VARIANTS.size, attempted.size
  end

  # Holds a copy of a private Rails method to its reason for existing.
  test "the form path still attempts every immediate variant, and does not enqueue them again" do
    attempted = []
    ActiveStorage::Variation.any_instance.stubs(:transform).with do |*|
      attempted << true
      true
    end.raises(Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize"))
    user = users(:david)

    assert_no_enqueued_jobs(only: [ ActiveStorage::CreateVariantsJob, ActiveStorage::TransformJob ]) do
      user.update!(avatar: Rack::Test::UploadedFile.new(file_fixture("moon.jpg"), "image/jpeg"))
    end

    assert_equal 1, attempted.size, "the avatar declares one immediate variant"
  end

  test "a transient failure is left to the retry" do
    transforms_raise Fizzy::Saas::Cell::ProcessingUnavailable.new("capacity")

    assert_nothing_raised { comment_with_embed }
  end

  test "a permanent verdict on the job path is reported once" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")
    Rails.error.expects(:report).with { |error, **| error.is_a?(Fizzy::Saas::Cell::UnprocessableAttachment) }
      .times(Attachments::VARIANTS.size)

    comment_with_embed
  end

  test "a permanent verdict on the form path is reported once" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")
    Rails.error.expects(:report).with { |error, **| error.is_a?(Fizzy::Saas::Cell::UnprocessableAttachment) }.once

    users(:david).update!(avatar: Rack::Test::UploadedFile.new(file_fixture("moon.jpg"), "image/jpeg"))
  end

  private
    def transforms_raise(error)
      ActiveStorage::Variation.any_instance.stubs(:transform).raises(error)
    end

    def comment_with_embed
      comment = cards(:logo).comments.create!(body: "Check this out")
      comment.body.body.attachables

      blob = ActiveStorage::Blob.create_and_upload!(io: File.open(file_fixture("moon.jpg")), filename: "moon.jpg",
        content_type: "image/jpeg")

      comment.body.body = ActionText::Content.new(comment.body.body.to_html).append_attachables(blob)
      comment.save!
      comment
    end
end
