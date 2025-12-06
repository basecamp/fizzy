require "test_helper"

class Account::StorageTrackingTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = Current.account
  end

  test "track storage deltas" do
    @account.adjust_storage(1000)
    assert_equal 1000, @account.reload.bytes_used

    @account.adjust_storage(-100)
    assert_equal 900, @account.reload.bytes_used
  end

  test "track storage deltas in jobs" do
    assert_enqueued_with(job: Account::AdjustStorageJob, args: [ @account, 1000 ]) do
      @account.adjust_storage_later(1000)
    end

    assert_no_enqueued_jobs only: Account::AdjustStorageJob do
      @account.adjust_storage_later(0)
    end
  end

  test "recalculate bytes used from cards and comments across boards" do
    board1 = boards(:writebook)
    board2 = boards(:private)

    card1 = board1.cards.create!(title: "Test 1", description: attachment_html(active_storage_blobs(:hello_txt)), status: :published)
    card1.comments.create!(body: attachment_html(active_storage_blobs(:hello_txt)))

    card2 = board2.cards.create!(title: "Test 2", description: attachment_html(active_storage_blobs(:list_pdf)), status: :published)

    @account.recalculate_bytes_used

    board1_expected = active_storage_blobs(:hello_txt).byte_size * 2
    board2_expected = active_storage_blobs(:list_pdf).byte_size

    assert_equal board1_expected, board1.reload.bytes_used
    assert_equal board2_expected, board2.reload.bytes_used
    assert_equal board1_expected + board2_expected, @account.bytes_used
  end
end
