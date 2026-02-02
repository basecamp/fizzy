require "test_helper"

class Webhook::TriggerableTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @board = boards(:writebook)
    @card = @board.cards.first
    @webhook = @board.webhooks.create!(
      name: "Test Webhook",
      url: "https://example.com/webhook",
      subscribed_actions: [ "card_published" ]
    )
    # Create a test event
    @event = @board.events.create!(
      creator: users(:david),
      eventable: @card,
      action: "card_published"
    )
    @user = users(:david)
  end

  test "trigger creates delivery for active accounts" do
    assert_difference -> { Webhook::Delivery.count }, 1 do
      @webhook.trigger(@event)
    end

    delivery = Webhook::Delivery.last
    assert_equal @event, delivery.event
    assert_equal @webhook, delivery.webhook
  end

  test "trigger skips cancelled accounts" do
    @account.cancel(initiated_by: @user)

    assert_no_difference -> { Webhook::Delivery.count } do
      @webhook.trigger(@event)
    end
  end

  test "triggered_by scope finds webhooks for event" do
    other_webhook = @board.webhooks.create!(
      name: "Other Webhook",
      url: "https://example.com/other",
      subscribed_actions: [ "card_closed" ]
    )

    matching_webhooks = Webhook.triggered_by(@event)

    assert_includes matching_webhooks, @webhook
    assert_not_includes matching_webhooks, other_webhook
  end

  test "active scope only returns active webhooks" do
    @webhook.update!(active: false)

    assert_not_includes Webhook.active, @webhook
  end
end
