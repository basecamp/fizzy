require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "rich text embed variants are processed immediately on attachment" do
    comment = cards(:logo).comments.create!(body: "Check this out")
    comment.body.body.attachables # force load

    blob = ActiveStorage::Blob.create_and_upload! \
      io: File.open(file_fixture("moon.jpg")),
      filename: "moon.jpg",
      content_type: "image/jpeg"

    comment.body.body = ActionText::Content.new(comment.body.body.to_html).append_attachables(blob)
    comment.save!

    embed = comment.body.embeds.sole

    Attachments::VARIANTS.each_key do |variant_name|
      variant = embed.variant(variant_name)
      assert variant.processed?, "Expected #{variant_name} variant to be processed immediately"
    end
  end
end
