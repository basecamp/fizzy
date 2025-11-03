require "test_helper"

class Card::Eventable::SystemCommenterTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:text)
  end

  test "card_assigned" do
    assert_system_comment "David assigned this to Kevin" do
      @card.toggle_assignment users(:kevin)
    end
  end

  test "card_unassigned" do
    @card.toggle_assignment users(:kevin)
    @card.comments.destroy_all # To skip deduplication logic

    assert_system_comment "David unassigned from Kevin" do
      @card.toggle_assignment users(:kevin)
    end
  end

  test "card_closed" do
    assert_system_comment "Moved to “Done” by David" do
      @card.close
    end
  end

  test "card_title_changed" do
    assert_system_comment "David changed the title from “The text is too small” to “Make text larger”" do
      @card.update! title: "Make text larger"
    end
  end

  test "don't notify on system comments" do
    @card.watch_by(users(:david))

    assert_no_difference -> { Notification.count } do
      @card.toggle_assignment users(:kevin)
    end
  end

  private
    def assert_system_comment(expected_comment)
      assert_difference -> { @card.comments.count }, 1 do
        yield
        assert @card.comments.last.creator.system?
        assert_match Regexp.new(expected_comment.strip, Regexp::IGNORECASE), @card.comments.last.body.to_plain_text.strip
      end
    end
end
