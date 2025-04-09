require "test_helper"

class Bubble::EngageableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "check the engagement status of a bubble" do
    assert bubbles(:logo).doing?
    assert_not bubbles(:text).doing?

    assert_not bubbles(:logo).considering?
    assert bubbles(:text).considering?
  end

  test "change the engagement" do
    assert_changes -> { bubbles(:text).reload.doing? }, to: true do
      bubbles(:text).engage
    end

    assert_changes -> { bubbles(:logo).reload.doing? }, to: false do
      bubbles(:logo).reconsider
    end
  end

  test "engaging with popped bubbles" do
    bubbles(:text).pop!

    assert_not bubbles(:text).considering?
    assert_not bubbles(:text).doing?

    bubbles(:text).engage
    assert_not bubbles(:text).reload.popped?
    assert bubbles(:text).doing?

    bubbles(:text).pop!
    bubbles(:text).reconsider
    assert_not bubbles(:text).reload.popped?
    assert bubbles(:text).considering?
  end

  test "scopes" do
    assert_includes Bubble.doing, bubbles(:logo)
    assert_not_includes Bubble.doing, bubbles(:text)

    assert_includes Bubble.considering, bubbles(:text)
    assert_not_includes Bubble.considering, bubbles(:logo)
  end

  test "auto_reconsider_all_stagnated" do
    bubbles(:logo, :shipping).each(&:engage)

    bubbles(:logo).update!(last_active_at: 1.day.ago - Bubble::Engageable::STAGNATED_AFTER)
    bubbles(:shipping).update!(last_active_at: 1.day.from_now - Bubble::Engageable::STAGNATED_AFTER)

    assert_difference -> { Bubble.considering.count }, +1 do
      Bubble.auto_reconsider_all_stagnated
    end

    assert bubbles(:shipping).reload.doing?
    assert bubbles(:logo).reload.considering?
  end
end
