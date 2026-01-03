require "test_helper"

class SlackIntegrationTest < ActiveSupport::TestCase
  test "validates webhook_secret presence" do
    integration = SlackIntegration.new(
      board: boards(:writebook),
      channel_id: "C1234567890",
      channel_name: "general",
      webhook_secret: nil
    )
    assert_not integration.valid?
    assert integration.errors[:webhook_secret].any?
  end

  test "validates channel_id presence" do
    integration = SlackIntegration.new(
      board: boards(:writebook),
      channel_id: nil,
      channel_name: "general",
      webhook_secret: "test_secret"
    )
    assert_not integration.valid?
    assert integration.errors[:channel_id].any?
  end

  test "validates channel_name presence" do
    integration = SlackIntegration.new(
      board: boards(:writebook),
      channel_id: "C1234567890",
      channel_name: nil,
      webhook_secret: "test_secret"
    )
    assert_not integration.valid?
    assert integration.errors[:channel_name].any?
  end

  test "validates uniqueness of channel per board" do
    existing = slack_integrations(:first)
    integration = SlackIntegration.new(
      board: existing.board,
      channel_id: existing.channel_id,
      channel_name: "different_name",
      webhook_secret: "test_secret"
    )
    assert_not integration.valid?
    assert integration.errors[:channel_id].any?
  end

  test "allows same channel on different boards" do
    integration = SlackIntegration.new(
      board: boards(:private),
      channel_id: slack_integrations(:first).channel_id,
      channel_name: "general",
      webhook_secret: "test_secret",
      color: "var(--color-card-10)"
    )
    assert integration.valid?
  end

  test "activate sets active to true" do
    integration = slack_integrations(:inactive)
    assert_not integration.active?

    integration.activate
    assert integration.active?
  end

  test "deactivate sets active to false" do
    integration = slack_integrations(:first)
    assert integration.active?

    integration.deactivate
    assert_not integration.active?
  end

  test "should_sync_event returns false when inactive" do
    integration = slack_integrations(:inactive)
    assert_not integration.should_sync_event?("message")
  end

  test "should_sync_event returns false when account disallows event" do
    integration = slack_integrations(:second)
    assert integration.active?
    assert integration.sync_thread_replies
    assert_not integration.account.slack_setting.allows_event?("thread_reply")

    assert_not integration.should_sync_event?("thread_reply")
  end

  test "should_sync_event returns false when integration disables event" do
    integration = slack_integrations(:first)
    integration.update!(sync_thread_replies: false)
    assert integration.active?
    assert_not integration.sync_thread_replies

    assert_not integration.should_sync_event?("thread_reply")
  end

  test "should_sync_event returns true when both account and integration allow" do
    integration = slack_integrations(:first)
    assert integration.active?
    assert integration.sync_messages
    assert integration.account.slack_setting.allows_event?("message")

    assert integration.should_sync_event?("message")
  end

  test "webhook_url generates correct URL" do
    integration = slack_integrations(:first)
    url = integration.webhook_url

    assert url.include?(integration.id)
    assert url.include?("slack/webhooks")
  end

  test "sync_message creates card for new message" do
    integration = slack_integrations(:first)
    Current.user = integration.account.system_user

    payload = {
      "event" => {
        "ts" => "1234567892.123456",
        "user" => "U1234567890",
        "text" => "This is a test message",
        "channel" => integration.channel_id
      }
    }

    assert_difference "Card.count", 1 do
      assert_difference "SlackItem.count", 1 do
        integration.sync_message(payload)
      end
    end

    slack_item = SlackItem.last
    assert_equal "1234567892.123456", slack_item.slack_message_ts
    assert_includes slack_item.card.title, "This is a test message"
  end

  test "sync_message skips bot messages" do
    integration = slack_integrations(:first)
    payload = {
      "event" => {
        "ts" => "1234567893.123456",
        "bot_id" => "B1234567890",
        "text" => "Bot message",
        "channel" => integration.channel_id
      }
    }

    assert_no_difference "Card.count" do
      integration.sync_message(payload)
    end
  end

  test "sync_thread_reply adds comment to existing card" do
    slack_item = slack_items(:message_one)
    integration = slack_item.slack_integration
    Current.user = integration.account.system_user

    message_data = {
      "thread_ts" => slack_item.slack_message_ts,
      "ts" => "1234567890.123457",
      "user" => "U0987654321",
      "text" => "This is a reply"
    }

    assert_difference "Comment.count", 1 do
      integration.sync_thread_reply(message_data)
    end

    comment = Comment.last
    assert_includes comment.body.to_s, "This is a reply"
  end

  test "sync_reaction adds reaction comment to card" do
    slack_item = slack_items(:message_one)
    integration = slack_item.slack_integration
    Current.user = integration.account.system_user

    payload = {
      "event" => {
        "reaction" => "thumbsup",
        "item" => {
          "ts" => slack_item.slack_message_ts
        }
      }
    }

    assert_difference "Comment.count", 1 do
      integration.sync_reaction(payload)
    end

    comment = Comment.last
    assert_includes comment.body.to_s, "thumbsup"
  end
end
