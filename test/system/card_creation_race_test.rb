require "application_system_test_case"

class CardCreationRaceTest < ApplicationSystemTestCase
  # Reproduces the race documented in #2778: when the user types a title in a
  # new draft and immediately presses Cmd/Ctrl+Enter, the publish request can
  # reach the server before the auto-save PATCH commits the title. The publish
  # callback then writes "Untitled", which the late PATCH rewrites — generating
  # a phantom `card_title_changed` event and a system comment as a side effect.
  setup do
    CardsController.class_eval do
      alias_method :_update_without_test_delay, :update
      def update
        sleep 0.5
        _update_without_test_delay
      end
    end
  end

  teardown do
    CardsController.class_eval do
      alias_method :update, :_update_without_test_delay
      remove_method :_update_without_test_delay
    end
  end

  test "Cmd+Enter on a new draft preserves the typed title without phantom events or system comments" do
    sign_in_as(users(:david))

    visit board_url(boards(:writebook))
    click_on "Add a card"

    title_field = find("textarea[name='card[title]']")
    title_field.send_keys "Race fix verified"
    title_field.send_keys [ :control, :enter ]

    assert_current_path board_path(boards(:writebook))
    assert_text "Race fix verified" # wait for late PATCH to commit before assertions

    card = Card.where(creator: users(:david)).order(:created_at).last
    assert_equal "Race fix verified", card.reload.title
    assert card.published?, "card should be published"
    refute Event.exists?(action: "card_title_changed", eventable: card),
      "publish should not generate a phantom card_title_changed event"
    refute card.comments.any? { |c| c.body.to_plain_text.include?("changed the title") },
      "publish should not generate a phantom 'changed the title' system comment"
  end
end
