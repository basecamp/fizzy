require "test_helper"

# See: +Card::StorageTrackingTest+, +Comment::StorageTrackingTest+
class StorageTrackingTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @board = boards(:writebook)
  end

  test "count the storage used by attachments" do
    card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)
    assert_equal active_storage_blobs(:hello_txt).byte_size, card.bytes_used
  end
end
