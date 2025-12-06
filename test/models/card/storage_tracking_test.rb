require "test_helper"

class Card::StorageTrackingTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = Current.account
    @board = boards(:writebook)
  end

  test "tracks storage when creating card with rich text attachment" do
    expected_bytes = active_storage_blobs(:hello_txt).byte_size

    assert_difference -> { @board.reload.bytes_used }, expected_bytes do
      assert_difference -> { @account.reload.bytes_used }, expected_bytes do
        perform_enqueued_jobs only: Account::AdjustStorageJob do
          @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)
        end
      end
    end
  end

  test "tracks storage delta when updating card with different attachment" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)

      expected_delta = active_storage_blobs(:list_pdf).byte_size - active_storage_blobs(:hello_txt).byte_size
      assert_difference -> { @board.reload.bytes_used }, expected_delta do
        assert_difference -> { @account.reload.bytes_used }, expected_delta do
          card.update!(description: attachment_html(active_storage_blobs(:list_pdf)))
        end
      end
    end
  end

  test "tracks negative delta when removing attachment from card" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)

      expected_delta = -active_storage_blobs(:hello_txt).byte_size
      assert_difference -> { @board.reload.bytes_used }, expected_delta do
        assert_difference -> { @account.reload.bytes_used }, expected_delta do
          card.update!(description: "No attachments")
        end
      end
    end
  end

  test "tracks negative storage when destroying card with attachment" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)

      expected_delta = -active_storage_blobs(:hello_txt).byte_size
      assert_difference -> { @board.reload.bytes_used }, expected_delta do
        assert_difference -> { @account.reload.bytes_used }, expected_delta do
          card.destroy!
        end
      end
    end
  end

  test "does not change storage when no attachments change" do
    assert_no_difference -> { @board.reload.bytes_used } do
      assert_no_difference -> { @account.reload.bytes_used } do
        perform_enqueued_jobs only: Account::AdjustStorageJob do
          @board.cards.create!(title: "Test", description: "Plain text", status: :published)
        end
      end
    end
  end

  test "does not change storage when updating title on card with attachment" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      card = @board.cards.create!(title: "Test", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)

      assert_no_difference -> { @board.reload.bytes_used } do
        assert_no_difference -> { @account.reload.bytes_used } do
          card.update!(title: "New title")
        end
      end
    end
  end

  test "does not change storage when updating description text but keeping same attachment" do
    perform_enqueued_jobs only: Account::AdjustStorageJob do
      card = @board.cards.create!(title: "Test", description: "Some text #{attachment_html(active_storage_blobs(:hello_txt))}", status: :published)

      assert_no_difference -> { @board.reload.bytes_used } do
        assert_no_difference -> { @account.reload.bytes_used } do
          card.update!(description: "Different text #{attachment_html(active_storage_blobs(:hello_txt))}")
        end
      end
    end
  end

  test "tracks storage separately for each board" do
    other_board = boards(:private)

    perform_enqueued_jobs only: Account::AdjustStorageJob do
      @board.cards.create!(title: "Card 1", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)
      other_board.cards.create!(title: "Card 2", description: attachment_html(active_storage_blobs(:list_pdf)), status: :published)

      assert_equal active_storage_blobs(:hello_txt).byte_size, @board.reload.bytes_used
      assert_equal active_storage_blobs(:list_pdf).byte_size, other_board.reload.bytes_used
      assert_equal active_storage_blobs(:hello_txt).byte_size + active_storage_blobs(:list_pdf).byte_size, @account.reload.bytes_used
    end
  end
end
