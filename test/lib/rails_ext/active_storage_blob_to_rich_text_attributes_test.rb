require "test_helper"

class ActiveStorageBlobToRichTextAttributesTest < ActiveSupport::TestCase
  setup do
    @blob = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
  end

  test "url is prefixed with the current account slug" do
    assert_match %r{\A#{Current.account.slug}/rails/active_storage/blobs/redirect/}, @blob.to_rich_text_attributes[:url]
  end

  test "url is unprefixed without a current account" do
    Current.without_account do
      assert_match %r{\A/rails/active_storage/blobs/redirect/}, @blob.to_rich_text_attributes[:url]
    end
  end
end
