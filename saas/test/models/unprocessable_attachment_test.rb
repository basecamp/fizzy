require "test_helper"

# A permanent verdict from the cell is a fact about one variant of one blob. It must not fail the save of
# the record that attached the file: `process: :immediately` transforms inline inside the record's
# after_commit, so the record is already committed by then, and a raise there 500s a POST that succeeded.
class Fizzy::Saas::UnprocessableAttachmentTest < ActiveSupport::TestCase
  setup { Current.session = sessions(:david) }

  test "a comment posts when an embed's variant cannot be made" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")

    comment = nil
    assert_nothing_raised { comment = comment_with_embed }

    assert comment.persisted?
    assert_equal 1, comment.body.embeds.count
  end

  # A form upload takes a different path from an embed: Rails transforms the immediate variants straight
  # from the uploaded io, before the blob is stored, and no job is involved. Left alone the save raised, the
  # attachment row existed, and the file was never uploaded.
  test "an avatar uploads when its variant cannot be made" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")
    user = users(:david)

    assert_nothing_raised { user.update!(avatar: Rack::Test::UploadedFile.new(file_fixture("moon.jpg"), "image/jpeg")) }

    blob = user.reload.avatar.blob
    assert blob.service.exist?(blob.key), "the original must still be uploaded"
  end

  # One variant failing says nothing about the others: a large animated GIF can outgrow the cell's output
  # limit at 1024×768 and fit at 800×600. Every variant gets its own attempt.
  test "the remaining variants are still attempted after one cannot be made" do
    attempted = []
    ActiveStorage::Variation.any_instance.stubs(:transform).with do |*|
      attempted << true
      true
    end.raises(Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize"))

    comment_with_embed

    assert_equal Attachments::VARIANTS.size, attempted.size
  end

  # The form path runs its own loop over the variants, and the rescue has to sit inside it: around it, the
  # first failure would skip the rest and leave the variants unmarked as processed, so Rails would run every
  # one again as a job after commit. This holds a copy of a private Rails method to its reason for existing.
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

  # A cell that is saturated or restarting says nothing about the file. The client gem retries the transient
  # class on these jobs, and nothing here may get in the way of that.
  test "a transient failure is left to the retry" do
    transforms_raise Fizzy::Saas::Cell::ProcessingUnavailable.new("capacity")

    assert_nothing_raised { comment_with_embed }
  end

  # The perform.hot_cell subscriber already reports every cell failure, so rescuing the verdict must not
  # report it again — the same event under two messages is two Sentry issues.
  test "rescuing a verdict does not report it a second time" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")
    Rails.error.expects(:report).never

    comment_with_embed
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
