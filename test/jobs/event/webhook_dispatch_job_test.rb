require "test_helper"

class Event::WebhookDispatchJobTest < ActiveJob::TestCase
  setup do
    @board = boards(:writebook)
    @event = @board.events.create!(creator: users(:david), eventable: @board.cards.first, action: "card_published")
  end

  test "delivers to a webhook in the event's account" do
    webhook = create_webhook(account: @board.account)

    Event::WebhookDispatchJob.perform_now(@event)

    assert_equal [ @event ], webhook.deliveries.map(&:event)
  end

  test "does not deliver to a webhook in another account that points at the event's board" do
    foreign_webhook = create_webhook(account: accounts(:initech))

    Event::WebhookDispatchJob.perform_now(@event)

    assert_empty foreign_webhook.deliveries
  end

  private
    def create_webhook(account:)
      Webhook.create!(account: account, board: @board, name: "Webhook", url: "https://example.com/webhook", subscribed_actions: [ "card_published" ])
    end
end
