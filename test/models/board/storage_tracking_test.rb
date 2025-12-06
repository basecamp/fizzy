require "test_helper"

class Board::StorageTrackingTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @board = boards(:writebook)
  end

  test "recalculate bytes used from cards and comments" do
    card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)
    card.comments.create!(body: attachment_html(active_storage_blobs(:hello_txt)))
    card.comments.create!(body: attachment_html(active_storage_blobs(:list_pdf)))

    @board.update_columns(bytes_used: 0)
    @board.recalculate_bytes_used

    expected_bytes = active_storage_blobs(:hello_txt).byte_size * 2 + active_storage_blobs(:list_pdf).byte_size
    assert_equal expected_bytes, @board.bytes_used
  end
end
