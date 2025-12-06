require "test_helper"

class Comment::StorageTrackingTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = Current.account
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  test "tracks storage when creating comment with attachment" do
    expected_bytes = active_storage_blobs(:hello_txt).byte_size

    assert_difference -> { @board.reload.bytes_used }, expected_bytes do
      assert_difference -> { @account.reload.bytes_used }, expected_bytes do
        perform_enqueued_jobs only: Account::AdjustStorageJob do
          @card.comments.create!(body: attachment_html(active_storage_blobs(:hello_txt)))
        end
      end
    end
  end

  test "tracks storage delta when updating comment with different attachment" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      comment = @card.comments.create!(body: attachment_html(active_storage_blobs(:hello_txt)))

      expected_delta = active_storage_blobs(:list_pdf).byte_size - active_storage_blobs(:hello_txt).byte_size
      assert_difference -> { @board.reload.bytes_used }, expected_delta do
        assert_difference -> { @account.reload.bytes_used }, expected_delta do
          comment.reload.update!(body: attachment_html(active_storage_blobs(:list_pdf)))
        end
      end
    end
  end

  test "tracks negative storage when destroying comment with attachment" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      comment = @card.comments.create!(body: attachment_html(active_storage_blobs(:hello_txt)))

      expected_delta = -active_storage_blobs(:hello_txt).byte_size
      assert_difference -> { @board.reload.bytes_used }, expected_delta do
        assert_difference -> { @account.reload.bytes_used }, expected_delta do
          comment.destroy!
        end
      end
    end
  end

  test "tracks negative storage for card and comments when destroying card" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)
      card.comments.create!(body: attachment_html(active_storage_blobs(:hello_txt)))
      card.comments.create!(body: attachment_html(active_storage_blobs(:list_pdf)))

      total_bytes = active_storage_blobs(:hello_txt).byte_size * 2 + active_storage_blobs(:list_pdf).byte_size
      assert_difference -> { @board.reload.bytes_used }, -total_bytes do
        assert_difference -> { @account.reload.bytes_used }, -total_bytes do
          card.destroy!
        end
      end
    end
  end
end
