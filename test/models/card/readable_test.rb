require "test_helper"

class Card::ReadableTest < ActiveSupport::TestCase
  test "read clears events notifications" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
        cards(:logo).read_by(users(:kevin))
      end
    end
  end

  test "read clear mentions in the description" do
    assert_changes -> { notifications(:logo_card_david_mention_by_jz).reload.read? }, from: false, to: true do
      cards(:logo).read_by(users(:david))
    end
  end

  test "read clear mentions in comments" do
    assert_changes -> { notifications(:logo_comment_david_mention_by_jz).reload.read? }, from: false, to: true do
      cards(:logo).read_by(users(:david))
    end
  end

  test "read clears notifications from the comments" do
    assert_changes -> { notifications(:layout_commented_kevin).reload.read? }, from: false, to: true do
      cards(:layout).read_by(users(:kevin))
    end
  end

  test "remove inaccessible notifications" do
    card = cards(:logo)
    kevin = users(:kevin)
    david = users(:david)

    assert card.accessible_to?(kevin)
    kevin_notifications = [ notifications(:logo_published_kevin), notifications(:logo_assignment_kevin) ]
    david_notifications = [ notifications(:logo_card_david_mention_by_jz), notifications(:logo_comment_david_mention_by_jz) ]

    # Kevin loses access
    card.board.accesses.find_by(user: kevin).destroy
    assert_not card.accessible_to?(kevin)
    assert card.accessible_to?(david)

    card.remove_inaccessible_notifications

    # Kevin's notifications removed
    kevin_notifications.each do |notification|
      assert_not Notification.exists?(notification.id)
    end

    # David's notifications preserved
    david_notifications.each do |notification|
      assert Notification.exists?(notification.id)
    end
  end
end
