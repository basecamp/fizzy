require "test_helper"

class Card::ReadableTest < ActiveSupport::TestCase
  test "read marks notification as read" do
    assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
      cards(:logo).read_by(users(:kevin))
    end
  end

  test "read marks mention notification as read" do
    assert_changes -> { notifications(:logo_mentioned_david).reload.read? }, from: false, to: true do
      cards(:logo).read_by(users(:david))
    end
  end

  test "read marks comment notification as read" do
    assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: false, to: true do
      cards(:layout).read_by(users(:kevin))
    end
  end

  test "unread marks notification as unread" do
    notifications(:logo_assignment_kevin).read

    assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: true, to: false do
      cards(:logo).unread_by(users(:kevin))
    end
  end

  test "unread marks mention notification as unread" do
    notifications(:logo_mentioned_david).read

    assert_changes -> { notifications(:logo_mentioned_david).reload.read? }, from: true, to: false do
      cards(:logo).unread_by(users(:david))
    end
  end

  test "unread marks comment notification as unread" do
    notifications(:layout_commented_kevin).read

    assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: true, to: false do
      cards(:layout).unread_by(users(:kevin))
    end
  end

  test "remove inaccessible notifications" do
    card = cards(:logo)
    kevin = users(:kevin)
    david = users(:david)

    assert card.accessible_to?(kevin)
    kevin_notification = notifications(:logo_assignment_kevin)
    david_notification = notifications(:logo_mentioned_david)

    # Kevin loses access
    card.board.accesses.find_by(user: kevin).destroy
    assert_not card.accessible_to?(kevin)
    assert card.accessible_to?(david)

    card.remove_inaccessible_notifications

    # Kevin's notification removed
    assert_not Notification.exists?(kevin_notification.id)

    # David's notification preserved
    assert Notification.exists?(david_notification.id)
  end
end
