require "test_helper"

class AccessTest < ActiveSupport::TestCase
  test "acesssed" do
    freeze_time

    assert_changes -> { accesses(:writebook_kevin).reload.accessed_at }, from: nil, to: Time.current do
      accesses(:writebook_kevin).accessed
    end

    travel 2.minutes

    assert_no_changes -> { accesses(:writebook_kevin).reload.accessed_at } do
      accesses(:writebook_kevin).accessed
    end
  end

  test "event notifications are destroyed when access is lost" do
    kevin = users(:kevin)
    board = boards(:writebook)

    # make sure we have test coverage for both cards and comments
    assert kevin.notifications.map(&:source).map(&:eventable_type).uniq.sort == [ "Card", "Comment" ]

    notifications_to_be_destroyed = kevin.notifications.select do |notification|
      notification.card&.board == board
    end
    assert notifications_to_be_destroyed.any?

    kevin_access = accesses(:writebook_kevin)

    perform_enqueued_jobs only: Board::CleanInaccessibleDataJob do
      kevin_access.destroy
    end

    remaining_notifications = kevin.notifications.reload.select do |notification|
      notification.card&.board == board
    end

    assert_empty remaining_notifications
  end

  test "mentions are destroyed when access is lost" do
    david = users(:david)
    board = boards(:writebook)

    # make sure we have test coverage for both cards and comments
    assert david.mentions.map(&:source_type).uniq.sort == [ "Card", "Comment" ]

    mentions_to_be_destroyed = david.mentions.select do |mention|
      mention.card&.board == board
    end
    assert mentions_to_be_destroyed.any?

    david_access = accesses(:writebook_david)

    perform_enqueued_jobs only: Board::CleanInaccessibleDataJob do
      david_access.destroy
    end

    remaining_mentions = david.mentions.reload.select do |mention|
      mention.card&.board == board
    end

    assert_empty remaining_mentions
  end

  test "watches are destroyed when access is lost" do
    kevin = users(:kevin)
    board = boards(:writebook)
    card = board.cards.first

    assert card.watched_by?(kevin)

    kevin_access = accesses(:writebook_kevin)

    perform_enqueued_jobs only: Board::CleanInaccessibleDataJob do
      kevin_access.destroy
    end

    assert_not card.watched_by?(kevin)
  end
end
