require "test_helper"

class SlackItemTest < ActiveSupport::TestCase
  test "validates slack_message_ts presence" do
    item = SlackItem.new(
      card: cards(:logo),
      slack_integration: slack_integrations(:first),
      channel_id: "C1234567890"
    )
    assert_not item.valid?
    assert item.errors[:slack_message_ts].any?
  end

  test "validates slack_message_ts uniqueness per integration" do
    existing = slack_items(:message_one)
    item = SlackItem.new(
      card: cards(:layout),
      slack_integration: existing.slack_integration,
      slack_message_ts: existing.slack_message_ts,
      channel_id: "C1234567890"
    )
    assert_not item.valid?
    assert item.errors[:slack_message_ts].any?
  end

  test "validates channel_id presence" do
    item = SlackItem.new(
      card: cards(:logo),
      slack_integration: slack_integrations(:first),
      slack_message_ts: "1234567890.123456",
      channel_id: nil
    )
    assert_not item.valid?
    assert item.errors[:channel_id].any?
  end

  test "creates valid slack item" do
    item = SlackItem.new(
      card: cards(:logo),
      slack_integration: slack_integrations(:first),
      slack_message_ts: "9999999999.999999",
      slack_user_id: "U9999999999",
      channel_id: "C1234567890"
    )
    assert item.valid?
  end
end
