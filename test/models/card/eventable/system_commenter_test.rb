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
    expected = strip_tags(I18n.t("events.system_comment.card_closed_html", creator_name: "David", column: I18n.t("columns.done")).html_safe)
    assert_system_comment expected do
      @card.close
    end
  end

  test "card_title_changed" do
    expected = strip_tags(I18n.t("events.system_comment.card_title_changed_html", creator_name: "David", old_title: "The text is too small", new_title: "Make text larger").html_safe)
    assert_system_comment expected do
      @card.update! title: "Make text larger"
    end
  end

  test "escapes html in comment body" do
    users(:david).update! name: "<em>Injected</em>"
    Current.session = sessions(:david)

    assert_difference -> { @card.comments.count }, 1 do
      @card.toggle_assignment users(:kevin)
    end

    comment = @card.comments.last
    html = comment.body.body.to_html
    assert_includes html, "&lt;em&gt;Injected&lt;/em&gt; <strong>assigned</strong> this to Kevin."
    refute_includes html, "<em>Injected</em>"
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
        comment = @card.comments.last
        assert comment.creator.system?
        assert_match Regexp.new(expected_comment.strip, Regexp::IGNORECASE), comment.body.to_plain_text.strip
      end
    end
end
